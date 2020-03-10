require "minitest/autorun"

require_relative "../irc.rb"

describe Hellbender::IRC do
  before do
    @irc = Hellbender::IRC.new
    # suppress log printing
    @irc.log.level = Logger::FATAL
  end

  it "remembers its config hash" do
    irc = Hellbender::IRC.new({foo: "bar"})
    assert_equal "bar", irc.config[:foo]
  end

  it "parses server messages" do
    assert_equal ["Nick!user@ser.ver", "PRIVMSG", ["#channel", "hello, world!"]],
                  @irc.parse_msg(":Nick!user@ser.ver PRIVMSG #channel :hello, world!")
    assert_equal [nil, "PRIVMSG", ["bar", "hello"]], @irc.parse_msg("PRIVMSG bar :hello")
    assert_equal [nil, "CMD", ["x", ""]], @irc.parse_msg("CMD x :")
    assert_equal ["ser.ver", "CMD", ["x", ""]], @irc.parse_msg(":ser.ver CMD x :")
    assert_equal [nil, "PING", ["123 45"]], @irc.parse_msg("PING :123 45")
  end

  it "processes server messages" do
    q = Queue.new
    @irc.add_listener(q)
    message = ["ser.ver", "PRIVMSG", ["you", "hello"]]

    @irc.process_msg(*message, "should not see this")
    assert_equal 1, q.size
    r = q.pop
    assert_equal message, r
    # check that the objects have been dup'd
    refute_same message[0], r[0]
    refute_same message[1], r[1]
    refute_same message[2][0], r[2][0]
    refute_same message[2][1], r[2][1]

    # check ping replies
    ponged = nil
    @irc.stub(:sendraw, proc {|msg| ponged = msg }) {
      @irc.process_msg(nil, "PING", ["foo"])
    }
    assert_equal "PONG foo", ponged
    assert_equal 0, q.size
  end

  it "sends only the first line of raw commands" do
    mock = Minitest::Mock.new
    mock.expect(:write, nil, ["CMD :foo\r\n"])
    @irc.instance_variable_set :@sock, mock
    @irc.__send__(:sendraw, "CMD :foo\nOTHERCMD :bar\n")
    assert_mock mock
  end

  it "tracks its own nickname" do
    @irc.instance_variable_set :@nick, "Bot1"
    @irc.process_msg(*@irc.parse_msg(":bot1!~hellbende@example.net NICK :Bot2"))
    assert_equal "Bot2", @irc.nick
  end
end
