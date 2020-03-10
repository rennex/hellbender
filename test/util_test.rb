require "minitest/autorun"

require_relative "../util.rb"

include Hellbender

describe Util do
  it "can convert IRC nicks to lower case" do
    assert_equal "{foo|bar}", Util.irccase('[foo\BAR]')
  end

  it "can compare IRC nicks case-insensitively" do
    assert Util.nickcmp('FOO[\]', "foo{|}")
    refute Util.nickcmp(nil, "bar")
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

end
