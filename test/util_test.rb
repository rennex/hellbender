require_relative "test_helper"
require_relative "../util.rb"

include Hellbender

describe Util do
  it "can convert IRC nicks to lower case" do
    assert_equal "{^foo|bar}", Util.irccase('[~foo\BAR]')
  end

  it "can compare IRC names case-insensitively" do
    assert Util.irccmp('FOO[\]', "foo{|}")
    assert Util.irccmp("#Channel", "#channel")
    refute Util.irccmp(nil, "bar")
  end

  it "guesses message encodings and converts them to UTF-8" do
    # emulate raw messages received from a TCP socket
    raw1 = "föö bär".encode("UTF-8").force_encoding("ASCII-8BIT")
    raw2 = "föö bär".encode("ISO-8859-1").force_encoding("ASCII-8BIT")
    refute_equal raw1, raw2
    [raw1, raw2].each do |raw|
      Util.guess_encoding(raw)
      assert_equal "föö bär", raw
      assert_equal "UTF-8", raw.encoding.to_s
    end
  end

  it "can validate nicknames" do
    assert Util.valid_nick?('[\w^e{i-r}d`o|]_')
    refute Util.valid_nick?('#foo')
    refute Util.valid_nick?('nick and extra stuff')
    refute Util.valid_nick?(nil)

    Util.validate_nick!("foo")
    assert_raises(ArgumentError) { Util.validate_nick!("#bar") }
    assert_raises(ArgumentError) { Util.validate_nick!("two words") }
  end

end
