
require "socket"
require "yaml"
require "logger"

require_relative "loggerformatter"
require_relative "util"
require_relative "message"

module Hellbender
  class IRC
    include UtilMethods

    attr_reader :config, :log, :connected
    def initialize(config = {})
      @config = config
      @connected = false
      @sock = nil
      @sock_mutex = Mutex.new   # for writing to the socket
      @log = Logger.new(STDOUT)
      @log.formatter = LoggerFormatter.new
    end

    def connect
      log.info "Connecting to server #{config["host"]}:#{config["port"]}"
      @sock = Socket.tcp(config["host"], config["port"], config["bindhost"],
              connect_timeout: (config["timeout"] || 10))
      log.info "Connection established"

      pass = config["pass"]
      if pass
        log.debug ">>\e[0;1m\"PASS <redacted>\""
        sendraw "PASS #{pass}", no_log: true
      end

      sendraw "NICK #{config['nick']}"
      sendraw "USER #{config['username']} #{config['bindhost'] || 'localhost'} " +
              "#{config['host']} :#{config['realname']}"

    rescue Errno::ECONNREFUSED, Errno::EALREADY
      # Socket.tcp with a connect timeout seems to raise EALREADY
      # if the server refused the connection
      log.error "Connection refused"
      return false

    rescue Errno::ETIMEDOUT
      log.error "Connection timed out"
      return false
    end

    def run(&block)
      loop do
        if connect()
          until @sock.eof?
            line = @sock.gets || break
            guess_encoding(line)
            m = IRC.parse_msg(line, self)
            if m
              log_msg(m, line)
              process_msg(m, &block)
            else
              log.error "Malformed message: #{line.inspect}" unless line.strip.empty?
            end
          end
          log.warn "Lost connection to server"
          @connected = false
        end
        break unless config["reconnect"]
        sleep 2
      end
    end

    def log_msg(m, line)
      case m.command
      when "375", "372", "376", "PING"
        # don't log the MOTD or PINGs
      when /^[45]\d\d$/
        # log error replies (400 to 599) at error level
        log.error "<<#{line.chomp}"
      else
        log.debug "<<#{line.chomp}"
      end
    end

    # handle an incoming server message
    def process_msg(m)
      case m.command
      when "001"
        log.info "Login to server was successful"
        @connected = true

      when "PING"
        sendraw "PONG #{m.params.first}", no_log: true
      end

      yield m
    end

    # parse messages received from the server
    def IRC.parse_msg(line, irc)
      line.match(/\A(:([^ ]+) )?([^ ]+)/) do |md|
        prefix = md[2].freeze
        command = md[3].upcase.freeze
        rest = md.post_match.chomp

        # the last parameter can have spaces by starting with a colon
        rest_md = rest.match(/ :/)
        params = if rest_md
          rest_md.pre_match.split << rest_md.post_match
        else
          rest.split
        end
        params.each(&:freeze)
        params.freeze

        return Message.new(prefix, command, params, irc)
      end
    end

    # send a raw command to the server (only the first line of text,
    # up to 510 characters)
    def sendraw(msg, no_log: false)
      if msg =~ /\A([^\r\n]+)/
        # the real limit is 512 bytes including the trailing CRLF.
        # Let's not deal with message splitting here.
        line = $1[0,510]
        log.debug ">>\e[0;1m#{line.inspect}" unless no_log
        # thread-safe sending!
        @sock_mutex.synchronize do
          @sock.write "#{line}\r\n"
        end
      end
    end
  end
end
