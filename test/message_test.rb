require "minitest/autorun"

require_relative "../message.rb"

include Hellbender

describe Message do
  it "can be initialized" do
    irc = Object.new
    m = Message.new("nick!user@example.com", "Hellbender", "Hello", irc)
    assert_kind_of User, m.sender
    assert_equal "nick", m.user.name
    assert_kind_of User, m.recipient
    assert_equal "Hellbender", m.recipient.nick
    assert_nil m.channel

    assert_equal "Hello", m.text
    assert_equal "Hello", m.message

    assert_same irc, m.irc

    m = Message.new("nick!user@example.com", "#Hellbender", "Hello", irc)
    assert_kind_of Channel, m.recipient
    assert_equal "#Hellbender", m.recipient.name
    refute_nil m.channel
  end

  it "can be replied to (private)" do
    irc = Minitest::Mock.new
    2.times do
      irc.expect(:sendraw, nil, ["PRIVMSG foo :bar"])
    end
    m = Message.new("foo!a@b.c", "us", "hello", irc)
    m.reply("bar")
    m.reply("bar", nick: true)
    assert_mock irc
  end

  it "can be replied to (channel)" do
    irc = Minitest::Mock.new
    irc.expect(:sendraw, nil, ["PRIVMSG #foo :bar"])
    irc.expect(:sendraw, nil, ["PRIVMSG #foo :usr: bar2"])
    m = Message.new("usr!a@b.c", "#foo", "hello", irc)
    m.reply("bar")
    m.reply("bar2", nick: true)
    assert_mock irc
  end
end

