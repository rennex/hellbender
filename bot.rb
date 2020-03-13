
require_relative "irc"
require_relative "target"

module Hellbender
  class Bot
    include UtilMethods

    attr_reader :irc, :channels
    def initialize(config = {})
      @irc = IRC.new(config["server"])
      @queue = Queue.new
      @irc.add_listener(@queue)
      @channels = []
    end

    def run
      Thread.new {
        loop do
          process_msg(*@queue.pop)
        end
      }

      @irc.run
    end

    def process_msg(prefix, command, params)
      by_us = prefix && irccase(prefix).start_with?(irccase("#{nick}!"))
      to_us = irccmp(params.first, nick)
      if prefix =~ /^([^!@]+)!([^!@]+)/
        from_nick = $1
        from_host = $2
      else
        from_nick = from_host = nil
      end

      case command
      when "JOIN"
        if by_us
          chan = params.first
          log.info "Joined #{chan}"
          @channels << chan
        end

      when "PRIVMSG"
        if to_us
          log.info "(MSG) <#{from_nick}> #{params.last}"
        elsif by_us
          log.warn "someone speaking on our behalf"
        end

      end
    end

    def nick; @irc.nick; end
    def log;  @irc.log;  end
  end
end

