
require "socket"
require "yaml"
require "logger"

require_relative "loggerformatter"
require_relative "util"

module Hellbender
  class IRC
    include UtilMethods

    attr_reader :config, :log, :nick
    def initialize(config = {})
      @config = config
      @sock = nil
      @sock_mutex = Mutex.new
      @listeners = []
      @listener_mutex = Mutex.new
      @log = Logger.new(STDOUT)
      @log.formatter = LoggerFormatter.new
    end

    def connect
      sc = config["server"]
      @sock = TCPSocket.new(sc["host"], sc["port"], sc["bindhost"])
      pass = sc["pass"]
      sendraw "PASS #{pass}" if pass
      @nick = sc['nick']
      sendraw "NICK #{@nick}"
      sendraw "USER #{sc['username']} #{sc['bindhost'] || 'localhost'} #{sc['host']} :#{sc['realname']}"
    end

    def run
      connect
      until @sock.eof?
        line = @sock.gets || break
        guess_encoding(line)
        parsed = parse_msg(line)
        process_msg(*parsed, line) if parsed
      end
    end

    # handle an incoming server message
    def process_msg(prefix, command, params, rawline = nil)
      # log messages, except the MOTD (it's annoying during development)
      unless ["375", "372", "376"].include? command
        log.debug "<<#{rawline.chomp}" if rawline
      end

      case command
      when "PING"
        sendraw "PONG #{params.first}"
        # no need to bother listeners with this
        return

      when "NICK"
        # track our own nick, in case the server changes it
        if irccase(prefix).start_with?(irccase("#{@nick}!"))
          @nick = params.first
        end

      end

      @listener_mutex.synchronize do
        @listeners.each do |queue|
          # ignore listeners that have too much backlog
          next if queue.size >= 5
          # send copies of the data
          queue << [prefix.dup, command.dup, params.map(&:dup)]
        end
      end
    end

    # parse messages received from the server
    def parse_msg(line)
      if line =~ /\A(:([^ ]+) )?([^ ]+)/
        prefix = $2
        command = $3
        rest = $'
        params = if rest =~ / :/
          $`.split << $'
        else
          rest.split
        end
        return prefix, command, params
      end
    end

    # add a listener of server messages
    def add_listener(queue)
      @listener_mutex.synchronize do
        @listeners << queue
      end
    end

    private
    # send a raw command to the server (only the first line of text)
    def sendraw(msg)
      if msg =~ /\A([^\r\n]+)/
        line = $1
        log.debug ">>#{line.inspect}"
        # thread-safe sending!
        @sock_mutex.synchronize do
          @sock.write "#{line}\r\n"
        end
      end
    end
  end
end


if $0 == __FILE__
  config = YAML.load(File.open("config.yml"))
  irc = Hellbender::IRC.new(config)
  irc.run
end

