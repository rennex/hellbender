require_relative "test_helper"
require_relative "../message.rb"

include Hellbender

describe Message do
  before do
    @irc = Minitest::Mock.new
  end

  it "can be initialized" do
    fakeirc = Object.new
    m = Message.new("nick!user@example.com", "PRIVMSG", ["Hellbender", "Hello"], fakeirc)
    assert_kind_of User, m.sender
    assert_equal "nick", m.user.name
    assert_kind_of User, m.target
    assert_equal "Hellbender", m.target.nick
    assert_nil m.channel

    assert_equal "PRIVMSG", m.command
    assert_equal "Hello", m.text
    assert_equal "Hello", m.message

    assert_same fakeirc, m.irc
    assert_same fakeirc, m.sender.irc
    assert_same fakeirc, m.target.irc

    m = Message.new("nick!user@example.com", "PRIVMSG", ["#Hellbender", "Hello"], @irc)
    assert_kind_of Channel, m.target
    assert_equal "#Hellbender", m.target.name
    refute_nil m.channel
  end

  it "can reply to private messages" do
    2.times do
      @irc.expect(:sendraw, nil, ["PRIVMSG foo :bar"])
    end
    m = Message.new("foo!a@b.c", "PRIVMSG", ["us", "hello"], @irc)
    m.reply("bar")
    m.reply("bar", nick: true)
    assert_mock @irc
  end

  it "can reply to channel messages" do
    @irc.expect(:sendraw, nil, ["PRIVMSG #foo :bar"])
    @irc.expect(:sendraw, nil, ["PRIVMSG #foo :usr: bar2"])
    m = Message.new("usr!a@b.c", "PRIVMSG", ["#foo", "hello"], @irc)
    m.reply("bar")
    m.reply("bar2", nick: true)
    assert_mock @irc
  end

  it "can be used as a hash key" do
    m1 = Message.new("ser.ver", "PRIVMSG", ["Hellbender", "Hello"])
    m2 = Message.new("usr!a@b.c", "PRIVMSG", ["#foo", "hello"])
    m3 = Message.new("a", "b", ["c"])
    h = {m1 => 1, m2 => m3}
    assert_equal 1, h[m1]
    assert_same m3, h[m2]
    assert_nil h[m3]
    assert_same m2, h.invert[Message.new("a", "b", ["c"])]
  end

  it "has an inspect method" do
    m = Message.new("a", "b", ["c", "d"])
    assert_equal '#<Message "b" from "a": ["c", "d"]>', m.inspect
  end

  it "parses target, channel, text etc" do
    chan = Channel.new("#chan")
    user = User.new("nick")
    us = User.new("Hellbender")
    text = "message foo bar"

    # channel events with a message
    %w(PART TOPIC PRIVMSG NOTICE).each do |cmd|
      m = Message.new("nick!user@server", cmd, ["#chan", text])
      assert_equal user, m.sender
      assert_equal user, m.user
      assert_equal chan, m.target
      assert_equal chan, m.channel
      assert_equal text, m.text
      assert_equal text, m.message
    end

    # private messages
    %w(PRIVMSG NOTICE).each do |cmd|
      m = Message.new("nick!user@server", cmd, ["Hellbender", text])
      assert_equal user,  m.sender
      assert_equal user,  m.user
      assert_equal us,    m.target
      assert_nil          m.channel
      assert_equal text,  m.text
      assert_equal text,  m.message
    end

    # kick with a reason
    m = Message.new("nick!user@server", "KICK", ["#chan", "Hellbender", text])
    assert_equal us, m.target
    assert_equal chan, m.channel
    assert_equal text, m.text

    # kick without a message
    m = Message.new("nick!user@server", "KICK", ["#chan", "Hellbender"])
    assert_equal us, m.target
    assert_equal chan, m.channel
    assert_nil m.text

    m = Message.new("nick!user@server", "INVITE", ["Hellbender", "#chan"])
    assert_equal us, m.target
    assert_equal chan, m.channel
    assert_nil m.text

    m = Message.new("nick!user@server", "JOIN", ["#chan"])
    assert_equal chan, m.channel
    assert_equal chan, m.target
    assert_nil m.text

    m = Message.new("nick!user@server", "NICK", ["Hellbender"])
    assert_equal us, m.target
    assert_nil m.channel
    assert_nil m.text

    m = Message.new("nick!user@server", "QUIT", [text])
    assert_nil m.target
    assert_nil m.channel
    assert_equal text, m.message

    # channel mode
    m = Message.new("nick!user@server", "MODE", ["#chan", "-m"])
    assert_equal chan, m.channel
    assert_equal chan, m.target
    assert_equal "-m", m.params.last
    assert_nil m.text

    # user mode
    m = Message.new("nick!user@server", "MODE", ["Hellbender", "+Zi"])
    assert_nil m.channel
    assert_equal us, m.target
    assert_equal "+Zi", m.params.last
    assert_nil m.text
  end

end
