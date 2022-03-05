
require_relative "target"

module Hellbender
  class Message
    attr_accessor :text, :bot
    attr_reader :sender, :target, :params, :user, :channel, :irc, :command
    alias message text

    def initialize(prefix, command, params, irc = Target.irc)
      @sender = prefix && Target.parse(prefix, irc)
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

    def ==(other)
      instance_variables.all? do |var|
        instance_variable_get(var) == other.instance_variable_get(var)
      end
    end
    alias eql? ==

    def hash
      instance_variables.map {|var| instance_variable_get(var).hash }.reduce(:^)
    end

    def inspect
      "#<Message \"#{@command}\" from \"#{@sender}\": #{params.inspect}>"
    end

    def to_raw
      res = []

      prefix = if @sender.respond_to?(:to_raw) then @sender.to_raw else @sender.to_s end
      unless prefix.empty?
        res << ":#{prefix}"
      end

      res << @command

      # treat the last parameter differently (add a leading colon to it)
      if @params.size > 1
        res.concat(params[0...-1])
      end

      unless @params.empty?
        res << ":#{@params.last}"
      end

      return res.join(" ")
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

    def public?
      ["PRIVMSG", "NOTICE"].include?(@command) && @target.is_a?(Channel)
    end

    def private?
      ["PRIVMSG", "NOTICE"].include?(@command) && !@target.is_a?(Channel)
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
