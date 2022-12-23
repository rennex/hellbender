
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
      case target
      when String
        if target =~ /^[&#+!]/
          Channel.new(target, irc)
        else
          User.new(target, irc) rescue Target.new(target, irc)
        end

      when Target
        # pass it through, so you can use Target.parse(arg)
        # when arg is either text or already a Target object
        return target
      end
    end

    # common implementations for Users and Channels
    def msg(text)
      irc.sendraw "PRIVMSG #{self} :#{text}"
    end
    alias privmsg msg

    def action(text)
      msg "\x01ACTION #{text}\x01"
    end

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
      Util.irccase(self) <=> Util.irccase(other)
    end

    def ==(other)
      case other
      when self.class, String
        Util.irccmp(self, other)
      else
        false
      end
    end

    alias eql? ==
    alias match? ===  # and by default === is an alias for ==

    def hash
      Util.irccase(self).hash
    end
  end


  class User < Target
    attr_reader :nick, :user, :host
    alias name nick

    def initialize(prefix, irc = (default_irc = Target.irc))
      case prefix
      when String
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
        @irc = irc

      when User
        # copy the values if the argument was a User object
        @nick = prefix.nick
        @user = prefix.user
        @host = prefix.host
        @irc = default_irc ? prefix.irc : irc

      else
        raise ArgumentError, "parameter class #{prefix.class} is not supported"
      end
    end

    def to_s
      @nick
    end

    def to_raw
      return to_s unless @user
      "#{@nick}!#{@user}@#{@host}"
    end
  end


  class Channel < Target
    def initialize(name, irc = (default_irc = Target.irc))
      case name
      when String
        @name = name
        @irc = irc

      when Channel
        chan = name
        @name = chan.name
        @irc = default_irc ? chan.irc : irc

      else
        raise ArgumentError, "parameter class #{name.class} is not supported"
      end
    end

    def join(key = nil)
      keyarg = " :#{key}" if key
      irc.sendraw("JOIN #{self}#{keyarg}")
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
