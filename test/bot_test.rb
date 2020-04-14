require_relative "test_helper"
require_relative "../bot.rb"

include Hellbender

describe Bot do
  before do
    @bot = create_test_bot
  end

  it "has a getter for config" do
    assert_kind_of Hash, @bot.config
  end

  it "tracks its own nickname" do
    assert_equal "Hellbender", @bot.nick
    @bot.process_msg(m("Hellbender", "NICK", ["bot"]))
    assert_equal "bot", @bot.nick.to_s
  end

  it "tracks its own channels" do
    assert_equal [], @bot.channels
    @bot.process_msg(m("Hellbender", "JOIN", ["#chan"]))
    @bot.process_msg(m("Hellbender", "JOIN", ["#foo"]))
    assert_equal [Channel["#chan"], Channel["#foo"]], @bot.channels.sort

    @bot.process_msg(m("some!one@x", "KICK", ["#foo", "Hellbender", "go away"]))
    assert_equal [Channel["#chan"]], @bot.channels

    @bot.process_msg(m("Hellbender", "PART", ["#chan", "bye"]))
    assert_equal [], @bot.channels
  end

  it "supports subscribing to messages" do
    all_count = 0
    all_m = nil
    @bot.subscribe(:all) {|m|
      all_count += 1
      all_m = m if m.command == "PRIVMSG"
    }

    join_part_count = 0
    @bot.subscribe(["JOIN", "PART"]) {
      join_part_count += 1
    }

    msg_count = 0
    msg_m = nil
    @bot.subscribe("PRIVMSG") {|m|
      msg_count += 1
      msg_m = m
    }

    @bot.process_msg(m("u", "FOOBAR", []))
    @bot.process_msg(m("u", "JOIN", ["#chan"]))
    @bot.process_msg(m("u", "PRIVMSG", ["#chan", "hello"]))
    @bot.process_msg(m("u", "PART", ["#chan"]))

    assert_equal 4, all_count
    assert_equal 2, join_part_count
    assert_equal 1, msg_count
    assert_equal "u", msg_m.user.to_s
    assert_equal "hello", msg_m.text

    # check that subscribers get dup'd Messages
    assert_equal all_m, msg_m
    refute_same all_m, msg_m
  end

  it "supports subscribe with a method turned into a block" do
    @state = []
    def subscriber(m)
      @state << m
    end

    @bot.subscribe("PRIVMSG", &method(:subscriber))

    @bot.process_msg(m("u", "PRIVMSG", ["#chan", "hello"]))

    assert_equal 1, @state.size
    assert_equal "hello", @state.first.text
  end

  it "supports a channel matcher for subscribe" do
    msgs = []
    @bot.subscribe("PRIVMSG", channel: "#foo") do |m|
      msgs << m.text
    end

    @bot.subscribe("PRIVMSG", channel: /z/) do |m|
      msgs << m.text
    end

    # let's not bother requiring channel_matcher.rb and testing
    # with it, since it just has a fancier match?()

    @bot.process_msg(m("u", "PRIVMSG", ["#chan", "1"]))
    @bot.process_msg(m("u", "PRIVMSG", ["#FOO", "2"]))
    @bot.process_msg(m("u", "PRIVMSG", ["#fooz", "3"]))

    assert_equal ["2", "3"], msgs
  end

  it "has setters for its own nickname and mode" do
    irc = Minitest::Mock.new
    irc.expect(:sendraw, nil, ["NICK newnick"])
    @bot.instance_variable_set :@irc, irc
    @bot.nick = "newnick"

    irc.expect(:sendraw, nil, ["MODE Hellbender +i"])
    @bot.mode("+i")

    assert_mock irc
  end

  it "has a join method" do
    irc = Minitest::Mock.new
    @bot.instance_variable_set :@irc, irc

    irc.expect(:sendraw, nil, ["JOIN #chan"])
    @bot.join "#chan"

    irc.expect(:sendraw, nil, ["JOIN #chan2"])
    @bot.join Channel["#chan2"]

    irc.expect(:sendraw, nil, ["JOIN #chan3 password"])
    @bot.join "#chan3", "password"

    assert_mock irc
  end


end
