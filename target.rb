
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

    def to_s
      @name
    end

    def self.parse(target, irc = Target.irc)
      if target =~ /^[&#+!]/
        Channel.new(target, irc)
      else
        User.new(target, irc) rescue Target.new(target, irc)
      end
    end

    def msg(text)
      irc.sendraw "PRIVMSG #{self} :#{text}"
    end
    alias privmsg msg

    def <=>(other)
      Util.irccase(self.to_s) <=> Util.irccase(other.to_s)
    end

    def ==(other)
      self.class == other.class && Util.irccmp(self.to_s, other.to_s)
    end

    def eql?(other)
      self == other
    end
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
      elsif prefix =~ /^(?![-0-9])[-a-z0-9\[\]\|`^{}\\_]+$/i
        @nick = prefix
        @user = @host = nil
      else
        raise "invalid prefix for parsing User"
      end
    end

    def to_s
      @nick
    end
  end


  class Channel < Target
  end

end
