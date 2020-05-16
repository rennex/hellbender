require_relative "test_helper"
require_relative "../channel_matcher.rb"

include Hellbender

describe ChannelMatcher do
  it "can include and exclude channels (case-insensitively)" do
    cm = ChannelMatcher.new(include: /foo/, exclude: "#foobar")
    assert cm.match? "#FOO"
    assert cm.match? "#xfoo"
    assert cm.match? "#foobarb"
    refute cm.match? "#foobar"
    refute cm.match? "#FOObar"
    refute cm.match? "#quux"
  end

  it "supports multiple args and different types" do
    cm = ChannelMatcher.new(include: [/a/, /Z/i, "#foo", Channel["#quux"]])
    assert cm.match? "#blah"
    assert cm.match? "#zzz"
    assert cm.match? "#Foo"
    assert cm.match? "#QUUX"
    refute cm.match? "quux"
    refute cm.match? "#bcd"
    refute cm.match? "#food"
  end

  it "supports include-only and exclude-only rules" do
    cm = ChannelMatcher.new(include: "#foo")
    assert cm.match? "#FOO"
    refute cm.match? "#food"

    cm = ChannelMatcher.new(include: :all)
    assert cm.match? "#asdf"

    cm = ChannelMatcher.new(exclude: "#foo")
    refute cm.match? "#FOO"
    assert cm.match? "#food"
  end

  it "matches all if both rule sets are empty" do
    cm = ChannelMatcher.new
    assert cm.match? "#asdf"
  end

  it "supports :all, and exclude takes precedence" do
    cm = ChannelMatcher.new(include: :all, exclude: "#foo")
    assert cm.match? "#quux"
    refute cm.match? "#foo"

    cm = ChannelMatcher.new(include: [:all, "#quux"], exclude: :all)
    refute cm.match? "#quux"
  end

end


describe CombinedMatcher do
  it "combines matchers correctly" do
    m1 = ChannelMatcher.new(include: /a/, exclude: "#foobar")
    m2 = ChannelMatcher.new(include: /b/, exclude: "#bar")
    cm = CombinedMatcher.new(m1, m2)

    assert cm.match? "#crab"
    assert cm.match? "#barb"
    assert cm.match? "#foobar5"

    refute cm.match? "#foober"
    refute cm.match? "#foocar"

    refute cm.match? "#foobar"
    refute cm.match? "#FOObar"
    refute cm.match? "#bar"
    refute cm.match? "#BAR"
  end

  it "returns the original if there's only one non-nil input" do
    m1 = ChannelMatcher.new(include: /a/)
    cm = CombinedMatcher.new(nil, m1, nil)
    assert_same cm, m1

    cm = CombinedMatcher.new(m1)
    assert_same cm, m1
  end

  it "returns nil if there's no non-nil inputs" do
    assert_nil CombinedMatcher.new(nil)
    assert_nil CombinedMatcher.new(nil, nil, nil)
  end
end
