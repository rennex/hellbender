require_relative "test_helper"
require_relative "../plugin.rb"

include Hellbender

describe Plugin do
  before do
    @bot = create_test_bot
    @plugin = Class.new do
      include Plugin
      attr_reader :calls, :cmds
      def initialize
        @calls = []
        @cmds = []
      end
    end
  end

  it "handles subscribe()" do
    @plugin.class_eval do
      subscribe ["FOO", "BAR"], method: \
      def handler(m)
        @calls << m.command
      end
      subscribe "QUUX", :handler
    end

    calls = []
    @plugin.subscribe "CMD" do |m|
      calls << m.command
    end

    instance = @plugin.new
    @bot.plugin @plugin
    @bot.plugin instance

    @bot.process_msg("u", "CMD", ["foo"])
    @bot.process_msg("u", "CMD2", ["foo"])

    @bot.process_msg("u", "FOO", ["foo"])
    @bot.process_msg("u", "QUUX", ["foo"])
    @bot.process_msg("u", "BAZ", ["foo"])
    @bot.process_msg("u", "BAR", ["foo"])

    assert_equal ["CMD", "CMD"], calls
    assert_equal ["FOO", "QUUX", "BAR"], instance.calls
  end

  it "handles react() and command()" do
    @plugin.class_eval do
      react(/foo/, :reactor)
      def reactor(m)
        @calls << m.text
      end

      command "bar", method: \
      def bar(m)
        @cmds << m.text
      end
    end
    instance = @plugin.new
    @bot.plugin instance

    @bot.process_msg("u", "NOTICE", ["#chan", "foobar"])
    @bot.process_msg("u", "NOTICE", ["#chan", ".bar foo"])
    @bot.process_msg("u", "PRIVMSG", ["#chan", "barquux"])
    @bot.process_msg("u", "PRIVMSG", ["#chan", ".bar"])
    @bot.process_msg("u", "PRIVMSG", ["#chan", "!bar and foo"])
    @bot.process_msg("u", "PRIVMSG", ["#chan", "barfood"])

    assert_equal ["!bar and foo", "barfood"], instance.calls
    assert_equal ["", "and foo"], instance.cmds
  end

end
