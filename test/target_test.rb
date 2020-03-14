require "minitest/autorun"

require_relative "../target"

include Hellbender

describe Target do
  it "can parse user hostmasks" do
    t = Target.parse("nick!user@example.com")
    assert_kind_of User, t
    assert_equal "nick", t.nick
    assert_equal "nick", t.name
    assert_equal "nick", t.to_s
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
    assert_equal Channel.new("bar"), Channel.new("BAR")
  end

  it "can be sorted" do
    u1 = User.new('[\w^e{i-r}d`o|]')
    u2 = User.new("weirdo2")
    u3 = User.new("WEIRdo")
    assert_equal [u3, u2, u1], [u2, u1, u3].sort
  end

  it "can be used as a hash key (case-insensitively)" do
    h = {User.new("foo") => Channel.new("#bar")}
    assert_equal Channel.new("#BAR"), h[User.new("FOO")]
    assert_equal User.new("FOO"), h.invert[Channel.new("#BAR")]
  end

  it "can be sent a message to" do
    irc = Minitest::Mock.new
    2.times do
      irc.expect(:sendraw, nil, ["PRIVMSG foo :bar"])
    end
    t = Target.parse("foo", irc)
    t.msg("bar")
    t.privmsg("bar")
    assert_mock irc
  end

  it "has User[] and Channel[]" do
    u = User["nick!user@example.com"]
    assert_equal "nick", u.nick
    c = Channel["#foo"]
    assert_equal "#foo", c.name
  end

end

