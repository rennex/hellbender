
require "socket"
require "yaml"
require "logger"

require_relative "loggerformatter"
require_relative "util"

module Hellbender
  class IRC
    include UtilMethods

    attr_reader :config, :log, :nick, :connected
    def initialize(config = {})
      @config = config
      @connected = false
      @sock = nil
      @sock_mutex = Mutex.new   # for writing to the socket
      @listeners = []
      @mutex = Mutex.new        # for general thread-safety
      @log = Logger.new(STDOUT)
      @log.formatter = LoggerFormatter.new
    end

    def sync
      @mutex.synchronize { yield }
    end

    def connect
      log.info "Connecting to server #{config["host"]}:#{config["port"]}"
      @sock = TCPSocket.new(config["host"], config["port"], config["bindhost"])
      log.info "Connection established"
      @connected = true

      pass = config["pass"]
      if pass
        log.debug '>>"PASS <redacted>"'
        sendraw "PASS #{pass}", no_log: true
      end

      @nick = config['nick']
      sendraw "NICK #{@nick}"
      sendraw "USER #{config['username']} #{config['bindhost'] || 'localhost'} " +
              "#{config['host']} :#{config['realname']}"

    rescue Errno::ECONNREFUSED
      log.error "Connection refused"
      return false
    end

    def run
      connect or return
      until @sock.eof?
        line = @sock.gets || break
        guess_encoding(line)
        parsed = parse_msg(line)
        process_msg(*parsed, line) if parsed
      end
      log.warn "Lost connection to server"
      @connected = false
    end

    # handle an incoming server message
    def process_msg(prefix, command, params, rawline = nil)
      # log messages, except the MOTD and PINGs
      unless ["375", "372", "376", "PING"].include? command
        log.debug "<<#{rawline.chomp}" if rawline
      end

      case command
      when "PING"
        sendraw "PONG #{params.first}", no_log: true
        # no need to bother listeners with this
        return

      when "NICK"
        # track our own nick, in case the server changes it
        if irccase(prefix).start_with?(irccase("#{@nick}!"))
          @nick = params.first
          log.info "Our nickname changed to #{@nick}"
        end

      end

      sync do
        @listeners.each do |queue|
          # send copies of the data
          queue << [prefix.dup, command.dup, params.map(&:dup)]
        end
      end
    end

    # parse messages received from the server
    def parse_msg(line)
      if line =~ /\A(:([^ ]+) )?([^ ]+)/
        prefix = $2
        command = $3.upcase
        rest = $'.chomp
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
      sync do
        @listeners << queue
      end
    end

    # send a raw command to the server (only the first line of text)
    def sendraw(msg, no_log: false)
      if msg =~ /\A([^\r\n]+)/
        line = $1
        log.debug ">>#{line.inspect}" unless no_log
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
  irc = Hellbender::IRC.new(config["server"])
  irc.run
end

