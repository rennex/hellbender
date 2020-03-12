
require_relative "target"

module Hellbender
  class Message
    attr_reader :text, :sender, :recipient, :channel, :irc
    alias user sender
    alias message text

    def initialize(sender, recipient, text, irc)
      @sender = Target.parse(sender, irc)
      @recipient = Target.parse(recipient, irc)
      @channel = @recipient if @recipient.is_a? Channel
      @text = text
      @irc = irc
    end

    # reply to this message, privately or on the same channel.
    # If replying to a channel and 'nick' is true, prepends "Sender: "
    # to the message.
    def reply(text, nick: false)
      if channel
        prefix = "#{sender}: " if nick
        channel.msg "#{prefix}#{text}"
      else
        sender.msg text
      end
    end

  end
end
