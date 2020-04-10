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
