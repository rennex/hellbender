require_relative "test_helper"
require_relative "../target"

include Hellbender

describe Target do
  it "can parse user hostmasks" do
    t = Target.parse("nick!user@example.com")
    assert_kind_of User, t
    assert_equal "nick", t.nick
    assert_equal "nick", t.name
    assert_equal "nick", t.to_s
    assert_equal "#<Hellbender::User: nick>", t.inspect
    assert_equal "user", t.user
    assert_equal "example.com", t.host
  end

  it "can parse bare nicknames" do
    assert_kind_of User, Target.parse('[\w^e{i-r}d`o|]_')
  end

  it "supports irc parameter and Target.irc" do
    irc = Object.new
    Target.irc = irc
    assert_same irc, Target.parse("nick").irc
    assert_same irc, Target.parse("#chan").irc
    assert_same irc, User.new("nick").irc
    assert_same irc, Channel.new("#chan").irc
    assert_equal "foo", Target.parse("bar", "foo").irc
    Target.irc = nil
  end

  it "can parse channel names" do
    t = Target.parse("#hellbender")
    assert_kind_of Channel, t
    assert_equal "#hellbender", t.name
    assert_kind_of Channel, Target.parse("##weirdchannel")
    assert_kind_of Channel, Target.parse("&weirderchannel")
    assert_kind_of Channel, Target.parse("+weirdererchannel")
    assert_kind_of Channel, Target.parse("!weirdestchannel")
  end

  it "can parse server names" do
    t = Target.parse("irc.server")
    assert_equal Target, t.class
    assert_equal "irc.server", t.name
  end

  it "can parse weird stuff" do
    # not entirely sure if this should be parsed as a User
    assert_kind_of User, Target.parse("***!znc@znc.in")

    "[]{}\\|^`_".each_char do |c|
      assert_kind_of User, Target.parse(c)
    end

    assert_kind_of Target, Target.parse("-foo")
    assert_kind_of Target, Target.parse("0bar")
    assert_kind_of Target, Target.parse(".quux")
  end

  it "can compare equality" do
    refute_equal User.new("foo"), Channel.new("foo")
    refute_equal User.new("foo"), User.new("bar")
    assert_equal User.new("FOO"), User.new("foo")
    assert_equal User.new("FOO"), "foo"
    assert_equal Channel.new("bar"), Channel.new("BAR")
    assert_equal Channel.new("#bar"), "#BAR"
  end

  it "supports === and match?" do
    u = User.new("foo")
    assert_operator u, :===, "FOO"
    assert u.match?("FOO")
    refute_operator u, :===, "foox"
    refute u.match?("foox")
  end

  it "can be sorted" do
    u1 = User.new('[\w^e{i-r}d`o|]')
    u2 = User.new("weirdo2")
    u3 = User.new("WEIRdo")
    assert_equal [u3, u2, u1], [u2, u1, u3].sort
  end

  it "can be used as a hash key and in a set (case-insensitively)" do
    require "set"
    h = {User.new("foo") => Channel.new("#bar")}
    assert_equal Channel.new("#BAR"), h[User.new("FOO")]
    assert_equal User.new("FOO"), h.invert[Channel.new("#BAR")]
    assert_nil h["foo"]
    s = Set.new
    s << h.keys.first
    s << h.values.first
    assert s.include?(User.new("Foo"))
    refute s.include?(User.new("bar"))
    assert s.include?(Channel.new("#BAR"))
    refute s.include?(Channel.new("foo"))
  end

  it "can be sent a message or an action" do
    irc = Minitest::Mock.new
    2.times do
      irc.expect(:sendraw, nil, ["PRIVMSG foo :bar"])
    end
    irc.expect(:sendraw, nil, ["NOTICE foo :quux"])
    t = Target.parse("foo", irc)
    t.msg("bar")
    t.privmsg("bar")
    t.notice("quux")

    irc.expect(:sendraw, nil, ["PRIVMSG foo :\x01ACTION foo\x01"])
    t.action("foo")
    assert_mock irc
  end

  it "has User[] and Channel[]" do
    u = User["nick!user@example.com"]
    assert_equal "nick", u.nick
    c = Channel["#foo"]
    assert_equal "#foo", c.name
  end

  it "supports Target operations" do
    irc = Minitest::Mock.new
    # helper to check for resulting raw commands
    def irc.expect_raw(str)
      expect(:sendraw, nil, [str])
    end

    c = Channel.new("#foo", irc)

    irc.expect_raw "JOIN #foo"
    c.join
    irc.expect_raw "JOIN #foo :bar"
    c.join("bar")

    irc.expect_raw "PART #foo"
    c.part
    irc.expect_raw "PART #foo"
    c.leave
    irc.expect_raw "PART #foo :bye"
    c.part("bye")

    2.times { irc.expect_raw "MODE #foo +o usr" }
    c.mode("+o usr")
    c.mode("+o", "usr")

    u = User.new("usr", irc)
    irc.expect_raw "MODE usr +i"
    u.mode("+i")

    irc.expect_raw "TOPIC #foo :new topic"
    c.topic = "new topic"
    irc.expect_raw "TOPIC #foo :"
    c.topic = nil

    2.times { irc.expect_raw "INVITE user #foo" }
    c.invite("user")
    c.invite(User["user"])
    assert_raises(ArgumentError) { c.invite("evil #user") }

    irc.expect_raw "KICK #foo usr"
    c.kick("usr")
    irc.expect_raw "KICK #foo usr :for reasons"
    c.kick(User["usr"], "for reasons")

    irc.expect_raw "MODE #foo +o user"
    c.op("user")
    irc.expect_raw "MODE #foo +v user"
    c.voice(User["user"])
    assert_raises(ArgumentError) { c.op("evil input") }
    assert_raises(ArgumentError) { c.voice("evil input") }

    assert_mock irc
  end

end



