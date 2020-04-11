
require_relative "util"

module Hellbender
  class Target
    class << self
      # support setting and getting Target.irc
      attr_accessor :irc
    end
    attr_accessor :irc, :name

    def initialize(name, irc = Target.irc)
      @name = name
      @irc = irc
    end
    def self.[](*args); new(*args); end

    def self.parse(target, irc = Target.irc)
      if target =~ /^[&#+!]/
        Channel.new(target, irc)
      else
        User.new(target, irc) rescue Target.new(target, irc)
      end
    end

    # common implementations for Users and Channels
    def msg(text)
      irc.sendraw "PRIVMSG #{self} :#{text}"
    end
    alias privmsg msg

    def notice(text)
      irc.sendraw "NOTICE #{self} :#{text}"
    end

    def mode(*args)
      irc.sendraw("MODE #{self} #{args.flatten.join(' ')}")
    end

    def to_s
      @name
    end

    def inspect
      "#<#{self.class}: #{to_s}>"
    end

    def <=>(other)
      Util.irccase(self.to_s) <=> Util.irccase(other.to_s)
    end

    def ==(other)
      case other
      when self.class, String
        Util.irccmp(self.to_s, other.to_s)
      else
        false
      end
    end

    alias eql? ==
    alias match? ===  # and by default === is an alias for ==

    def hash
      Util.irccase(self.to_s).hash
    end
  end


  class User < Target
    attr_reader :nick, :user, :host
    alias name nick

    def initialize(prefix, irc = Target.irc)
      @irc = irc
      # parse Nick!user@host
      if prefix =~ /^([^!@]+)!([^@]+)@([^!@]+)$/
        @nick = $1
        @user = $2
        @host = $3
      elsif Util.valid_nick?(prefix)
        @nick = prefix
        @user = @host = nil
      else
        raise "invalid prefix for parsing User: #{prefix}"
      end
    end

    def to_s
      @nick
    end
  end


  class Channel < Target
    def join(key = nil)
      irc.sendraw("JOIN #{self} #{key}".strip)
    end

    def part(message = nil)
      msg = " :#{message}" if message
      irc.sendraw("PART #{self}#{msg}")
    end
    alias leave part

    def topic=(newtopic)
      irc.sendraw("TOPIC #{self} :#{newtopic}")
    end

    def invite(user)
      # Check the nickname since it might be malicious input,
      # for example "realnick #wrongchannel\n"
      Util.validate_nick!(user)
      irc.sendraw("INVITE #{user} #{self}")
    end

    def kick(user, comment = nil)
      com = " :#{comment}" if comment
      irc.sendraw("KICK #{self} #{user}#{com}")
    end

    def op(user)
      Util.validate_nick!(user)
      mode("+o", user)
    end

    def voice(user)
      Util.validate_nick!(user)
      mode("+v", user)
    end

  end

end
