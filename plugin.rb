
require_relative "bot"
require_relative "channel_matcher"

module Hellbender
  module Plugin
    attr_reader :bot

    module ClassMethods
      # like Bot#subscribe
      def subscribe(commands, **args, &block)
        _hb_add_sub(:subscribe, Array(commands), args, block)
      end

      # react to given regexp in PRIVMSGs
      def react(regexp, **args, &block)
        _hb_add_sub(:react, regexp, args, block)
      end

      # named command
      def command(cmdname, **args, &block)
        _hb_add_sub(:command, cmdname, args, block)
      end

      def _hb_add_sub(sub_type, matcher, args, block)
        callback = args[:method] || block
        # store the subscription in a class instance variable
        @_hb_subscriptions << [sub_type, matcher, args, callback]
      end
    end

    def self.included(klass)
      klass.extend ClassMethods
      klass.singleton_class.send(:attr_accessor, :_hb_subscriptions)
      klass._hb_subscriptions = []
    end

    # called by Bot#plugin()
    def _hb_plug_into(bot, plugin_args)
      @bot = bot
      plugin_cm = _hb_parse_channel_matcher(plugin_args)

      Array(self.class._hb_subscriptions).each do |sub_type, matcher, args, callback|
        # turn symbols into Methods of the plugin instance
        callback = self.method(callback) if callback.is_a? Symbol

        cm = _hb_parse_channel_matcher(args)
        channel_matcher = CombinedMatcher.new(plugin_cm, cm)

        self.method(:"_hb_sub_#{sub_type}").call(matcher, channel_matcher, callback, args, plugin_args)
      end
    end

    private

    def _hb_parse_channel_matcher(args)
      inc = args.values_at(:channel, :channels).flatten.uniq.compact
      exc = args.values_at(:exclude_channel, :exclude_channels).flatten.uniq.compact

      unless inc.empty? && exc.empty?
        ChannelMatcher.new(include: inc, exclude: exc)
      end
    end


    def _hb_sub_subscribe(commands, channel, callback, *args)
      bot.subscribe(commands, channel: channel, &callback)
    end

    def _hb_sub_react(regexp, channel, callback, *args)
      bot.subscribe("PRIVMSG", channel: channel) do |m|
        regexp.match(m.text) do |md|
          _hb_call_with_md(callback, m, md)
        end
      end
    end

    def _hb_sub_command(command, channel, callback, args, plugin_args)
      cmd_re = command.is_a?(Regexp) ? command : Regexp.escape(command)

      prefix = plugin_args[:prefix] || args[:prefix] || bot.config.dig("bot", "command_prefix") || /[.!]/
      prefix_re = prefix.is_a?(Regexp) ? prefix : Regexp.escape(prefix)

      bot.subscribe("PRIVMSG", channel: channel) do |m|
        m.text.match(/^#{prefix_re}#{cmd_re}(?:$| +)/i) do |md|
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

