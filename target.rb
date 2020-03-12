
module Hellbender
  class Target
    attr_accessor :irc, :name

    def initialize(name)
      @name = name
    end

    def to_s
      @name
    end

    def self.parse(target, irc = nil)
      ret = if target =~ /^[&#+!]/
        Channel.new(target)
      else
        User.new(target) rescue Target.new(target)
      end
      ret.irc = irc
      ret
    end

    def msg(text)
      irc.sendraw "PRIVMSG #{self.to_s} :#{text}"
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

    def initialize(prefix)
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
