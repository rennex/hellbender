
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
      # todo: private messages vs public?
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

    def _hb_plug_into(bot)
      @bot = bot
      Array(self.class._hb_subscriptions).each do |sub_type, matcher, callback|
        # turn symbols into Methods of the plugin instance
        callback = self.method(callback) if callback.is_a? Symbol

        case sub_type
        when :react
          regexp = matcher
          my_callback = proc do |m|
            m.text.match(regexp) do |md|
              if callback.arity == 1
                callback.call(m)
              else
                # arity could be 2 or < 0
                callback.call(m, md)
              end
            end
          end
          matcher = ["PRIVMSG"]

        when :command
          cmdstr = Regexp.escape(matcher)
          my_callback = proc do |m|
            m.text.match(/^[!.]#{cmdstr} *($| +(.+))/i) do |md|
              # make m.text contain only the command's arguments
              m.text = md[2] || ""
              callback.call(m)
            end
          end
          matcher = ["PRIVMSG"]

        when :subscribe
          my_callback = callback

        else
          raise
        end

        bot.subscribe(matcher, my_callback)
      end
    end

  end
end

