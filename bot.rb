
require_relative "irc"
require_relative "message"

require "set"

module Hellbender
  class Bot
    include UtilMethods

    attr_reader :irc, :nick, :config
    def initialize(config)
      @config = config
      @irc = IRC.new(config["server"])
      Target.irc = @irc
      @nick = config["server"]&.[]("nick")
      @queue = Queue.new
      @mutex = Mutex.new
      @irc.add_listener(@queue)
      @channels = Set.new
      @subs = []
    end

    def sync
      @mutex.synchronize { yield }
    end

    def channels
      sync { @channels.to_a }
    end

    def log
      @irc.log
    end

    def run(reconnect: false)
      Thread.new {
        loop do
          process_msg(*@queue.pop)
        end
      }

      @irc.run(reconnect: reconnect)
    end

    def process_msg(prefix, command, params)
      m = Message.new(prefix, command, params, @irc)

      # track our own activity
      case command
      when "NICK"
        if m.user == @nick
          @nick = m.target
          log.info "Our nickname changed to #{@nick}"
        end

      when "JOIN"
        if m.user == @nick
          log.info "We joined #{m.channel}"
          sync { @channels << m.channel }
        end

      when "PART"
        if m.user == @nick
          log.info "We left #{m.channel}"
          sync { @channels.delete(m.channel) }
        end

      when "KICK"
        if m.target == @nick
          log.warn "We were kicked from #{m.channel} by #{m.user}:\e[0m #{m.message}"
          sync { @channels.delete(m.channel) }
        end

      when "PRIVMSG"
        if m.target == @nick
          log.info "<#{m.user}>\e[0m #{m.message}"
        end

      end

      send_to_subscribers(m)
    end

    def send_to_subscribers(msg)
      # call all the interested subscribers
      threads = []
      sync {
        @subs.each do |wanted, channel, code|
          if wanted.include?(:all) || wanted.include?(msg.command)
            if channel.nil? || channel.match?(Util::irccase(msg.channel.to_s))
              threads << Thread.new { code.call(msg.dup) }
            end
          end
        end
      }
      # return the threads so tests can wait for them to finish
      return threads
    end

    def subscribe(commands, channel: nil, &block)
      sync {
        @subs << [Array(commands), channel, block]
      }
    end

    def nick=(newnick)
      irc.sendraw("NICK #{newnick}")
    end

    def mode(*args)
      User.new(@nick, @irc).mode(*args)
    end

    def join(channel, key = nil)
      Channel.new(channel.to_s, @irc).join(key)
    end

    def plugin(class_or_instance)
      case class_or_instance
      when Class
        instance = class_or_instance.new
      else
        instance = class_or_instance
      end

      unless instance.is_a? Hellbender::Plugin
        raise TypeError, "plugin must be a Hellbender::Plugin"
      end

      instance._hb_plug_into(self)
    end

  end
end

