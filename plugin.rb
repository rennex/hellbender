
require_relative "bot"

module Hellbender
  module Plugin
    attr_reader :bot

    module ClassMethods
      # like Bot#subscribe
      def subscribe(commands, methodname = nil, method: nil, &block)
        callback = method || methodname || block
        # store the subscription in a class instance variable
        @_hb_subscriptions << [:subscribe, Array(commands), callback]
      end

      # react to given regexp in PRIVMSGs
      def react(regexp, methodname = nil, method: nil, &block)
        callback = method || methodname || block
        @_hb_subscriptions << [:react, regexp, callback]
      end

      # named command
      def command(cmdname, methodname = nil, method: nil, &block)
        callback = method || methodname || block
        @_hb_subscriptions << [:command, cmdname, callback]
      end
    end

    def self.included(klass)
      klass.extend ClassMethods
      klass.singleton_class.send(:attr_accessor, :_hb_subscriptions)
      klass._hb_subscriptions = []
    end

    # called by Bot#plugin()
    def _hb_plug_into(bot)
      @bot = bot
      Array(self.class._hb_subscriptions).each do |sub_type, matcher, callback|
        # turn symbols into Methods of the plugin instance
        callback = self.method(callback) if callback.is_a? Symbol

        self.method("_hb_sub_#{sub_type}").call(matcher, callback)
      end
    end

    def _hb_sub_subscribe(commands, callback)
      bot.subscribe(commands, callback)
    end

    def _hb_sub_react(regexp, callback)
      bot.subscribe "PRIVMSG" do |m|
        m.text.match(regexp) do |md|
          if callback.arity == 1
            callback.call(m)
          else
            # arity could be 2 or < 0
            callback.call(m, md)
          end
        end
      end
    end

    def _hb_sub_command(command, callback)
      bot.subscribe "PRIVMSG" do |m|
        m.text.match(/^[!.]#{Regexp.escape(command)} *($| +(.+))/i) do |md|
          # make m.text contain only the command's arguments
          m.text = md[2] || ""
          callback.call(m)
        end
      end
    end

  end
end

