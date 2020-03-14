
require_relative "target"

module Hellbender
  class Message
    attr_reader :text, :sender, :target, :params, :user, :channel, :irc
    alias message text

    def initialize(prefix, command, params, irc = Target.irc)
      @sender = Target.parse(prefix, irc) if prefix
      @user = @sender if @sender.is_a? User
      @command = command
      @params = params
      @irc = irc

      case command
      when "PRIVMSG", "NOTICE", "TOPIC", "PART",
            "JOIN", "NICK", "MODE"
        @target = Target.parse(params.first, irc)
        @channel = @target if @target.is_a? Channel

        # text isn't relevant for these
        unless ["JOIN", "NICK", "MODE"].include? command
          @text = params.last
        end

      when "KICK"
        @channel = Channel.new(params[0], irc)
        @target = User.new(params[1], irc)
        @text = params[2]

      when "INVITE"
        # we only receive these when we're being invited
        @target = User.new(params[0], irc)
        @channel = Channel.new(params[1], irc)

      when "QUIT"
        # quit has no target or channel, only a quit message
        @text = params.last

      end
    end

    # support checking e.g. m.privmsg? or m.join?
    def method_missing(m)
      meth = m.to_s
      if meth.end_with?("?")
        @command == meth.chop.upcase
      else
        super
      end
    end

    # reply to this PRIVMSG, privately or on the same channel.
    # If replying to a channel and 'nick' is true, prepends "Sender: "
    # to the message.
    # Does nothing when replying to other commands (including notices).
    def reply(text, nick: false)
      if @command == "PRIVMSG"
        if channel
          prefix = "#{sender}: " if nick
          channel.msg "#{prefix}#{text}"
        else
          sender.msg text
        end
      end
    end

  end
end

=begin

Examples of messages:

:u MODE nick -o
:u MODE #chan -l
:u MODE #chan +o Nick

:u PART #chan :msg
:u TOPIC #chan :new topic
:u KICK #chan nick :msg
:u PRIVMSG nickorchan :msg
:u NOTICE nickorchan :msg
:u INVITE targetnick #chan (...)
:u JOIN #chan
:u NICK Newnick

:u QUIT :msg

=end
