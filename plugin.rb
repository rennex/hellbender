
require_relative "bot"

module Hellbender
  module Plugin
    attr_reader :bot

    module ClassMethods
      # like Bot#subscribe
      def subscribe(commands, methodname = nil, **args, &block)
        _hb_add_sub(:subscribe, Array(commands), methodname, args, block)
      end

      # react to given regexp in PRIVMSGs
      def react(regexp, methodname = nil, **args, &block)
        _hb_add_sub(:react, regexp, methodname, args, block)
      end

      # named command
      def command(cmdname, methodname = nil, **args, &block)
        _hb_add_sub(:command, cmdname, methodname, args, block)
      end

      def _hb_add_sub(sub_type, matcher, methodname, args, block)
        callback = args[:method] || methodname || block
        # store the subscription in a class instance variable
        @_hb_subscriptions << [sub_type, matcher, callback]
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

        self.method(:"_hb_sub_#{sub_type}").call(matcher, callback)
      end
    end

    def _hb_sub_subscribe(commands, callback)
      bot.subscribe(commands, callback)
    end

    def _hb_sub_react(regexp, callback)
      bot.subscribe "PRIVMSG" do |m|
        regexp.match(m.text) do |md|
          _hb_call_with_md(callback, m, md)
        end
      end
    end

    def _hb_sub_command(command, callback)
      cmd_re = command.is_a?(Regexp) ? command : Regexp.escape(command)
      bot.subscribe "PRIVMSG" do |m|
        m.text.match(/^[!.]#{cmd_re}(?:$| +)/i) do |md|
          # make m.text contain only the command's arguments
          m.text = md.post_match
          _hb_call_with_md(callback, m, md)
        end
      end
    end

    def _hb_call_with_md(callback, m, md)
      if callback.arity == 1
        callback.call(m)
      else
        # arity could be 2 or < 0
        callback.call(m, md)
      end
    end

  end
end

