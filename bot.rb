
require_relative "irc"
require_relative "message"

require "set"

module Hellbender
  class Bot
    include UtilMethods

    attr_reader :irc, :nick
    def initialize(config = {})
      @irc = IRC.new(config["server"])
      Target.irc = @irc
      @nick = config["server"]["nick"]
      @queue = Queue.new
      @mutex = Mutex.new
      @irc.add_listener(@queue)
      @channels = Set.new
    end

    def sync
      @mutex.synchronize { yield }
    end

    def channels
      sync { @channels.dup }
    end
    def log;  @irc.log;  end

    def run
      Thread.new {
        loop do
          process_msg(*@queue.pop)
        end
      }

      @irc.run
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

    end

  end
end
