require "minitest/autorun"

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

  it "supports checking m.privmsg? etc" do
    m = Message.new("ser.ver", "PRIVMSG", ["Hellbender", "Hello"])
    assert m.privmsg?
    refute m.foobar?
    assert_raises(NoMethodError) { m.privmsg }

    m = Message.new("ser.ver", "FOOBARBAZ", [])
    assert m.foobarbaz?
    refute m.privmsg?
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
    assert m.kick?
    assert_equal us, m.target
    assert_equal chan, m.channel
    assert_equal text, m.text

    # kick without a message
    m = Message.new("nick!user@server", "KICK", ["#chan", "Hellbender"])
    assert m.kick?
    assert_equal us, m.target
    assert_equal chan, m.channel
    assert_nil m.text

    m = Message.new("nick!user@server", "INVITE", ["Hellbender", "#chan"])
    assert m.invite?
    assert_equal us, m.target
    assert_equal chan, m.channel
    assert_nil m.text

    m = Message.new("nick!user@server", "JOIN", ["#chan"])
    assert m.join?
    assert_equal chan, m.channel
    assert_equal chan, m.target
    assert_nil m.text

    m = Message.new("nick!user@server", "NICK", ["Hellbender"])
    assert m.nick?
    assert_equal us, m.target
    assert_nil m.channel
    assert_nil m.text

    m = Message.new("nick!user@server", "QUIT", [text])
    assert m.quit?
    assert_nil m.target
    assert_nil m.channel
    assert_equal text, m.message

    # channel mode
    m = Message.new("nick!user@server", "MODE", ["#chan", "-m"])
    assert m.mode?
    assert_equal chan, m.channel
    assert_equal chan, m.target
    assert_equal "-m", m.params.last
    assert_nil m.text

    # user mode
    m = Message.new("nick!user@server", "MODE", ["Hellbender", "+Zi"])
    assert m.mode?
    assert_nil m.channel
    assert_equal us, m.target
    assert_equal "+Zi", m.params.last
    assert_nil m.text
  end

end
