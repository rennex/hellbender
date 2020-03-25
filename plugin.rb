
require_relative "bot"

module Hellbender
  module Plugin
    attr_reader :bot

    module ClassMethods
      # like Bot#subscribe
      def subscribe(commands, methodname = nil, method: nil, &block)
        callback = method || methodname || block
        # store the subscription in a class instance variable
        @_hb_subscriptions << [Array(commands), callback]
      end

      # react to given regexp in PRIVMSGs
      def react(regexp, methodname = nil, method: nil, &block)
        callback = method || methodname || block
        @_hb_subscriptions << [regexp, callback]
      end

      # named command
      def command(cmdname, methodname = nil, method: nil, &block)
        callback = method || methodname || block
        @_hb_subscriptions << [cmdname, callback]
      end
    end

    def self.included(klass)
      klass.extend ClassMethods
      klass.singleton_class.send(:attr_accessor, :_hb_subscriptions)
      klass._hb_subscriptions = []
    end

    def _hb_plug_into(bot)
      @bot = bot
      Array(self.class._hb_subscriptions).each do |command, callback|
        # turn symbols into Methods of the plugin instance
        callback = self.method(callback) if callback.is_a? Symbol

        case command
        when Regexp
          # handle react()
          regexp = command
          my_callback = proc do |m|
            if m.text.match(regexp)
              callback.call(m)
            end
          end
          command = ["PRIVMSG"]

        when String
          # handle command()
          cmdstr = Regexp.escape(command)
          my_callback = proc do |m|
            m.text.match(/^[!.]#{cmdstr} *($| +(.+))/i) do |md|
              # make m.text contain only the command's arguments
              m = m.dup
              m.text = md[2] || ""
              callback.call(m)
            end
          end
          command = ["PRIVMSG"]

        else
          # handle subscribe()
          my_callback = callback
        end

        bot.subscribe(command, my_callback)
      end
    end

  end
end

