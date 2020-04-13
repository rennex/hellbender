require_relative "test_helper"
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
                  @irc.parse_msg(":Nick!user@ser.ver PRIVMSG #channel :hello, world!\r\n")
    assert_equal [nil, "PRIVMSG", ["bar", "hello"]], @irc.parse_msg("PRIVMSG bar :hello")
    assert_equal [nil, "CMD", ["x", ""]], @irc.parse_msg("CMD x :")
    assert_equal ["ser.ver", "CMD", ["x", ""]], @irc.parse_msg(":ser.ver cmd x :")
    assert_equal [nil, "PING", ["123 45"]], @irc.parse_msg("PING :123 45")
  end

  it "processes server messages" do
    message = ["ser.ver", "PRIVMSG", ["you", "hello"]]

    @irc.process_msg(*message) {|*msg|
      assert_equal message, msg
    }

    # check ping replies
    ponged = nil
    @irc.stub(:sendraw, proc {|msg| ponged = msg }) {
      @irc.process_msg(nil, "PING", ["foo"]) {|*msg|
        # do nothing
      }
    }
    assert_equal "PONG foo", ponged
  end

  it "sends only the first line of raw commands" do
    mock = Minitest::Mock.new
    mock.expect(:write, nil, ["CMD :foo\r\n"])
    @irc.instance_variable_set :@sock, mock
    @irc.sendraw "CMD :foo\nOTHERCMD :bar\n"
    assert_mock mock
  end

  it "limits the length of sent messages" do
    mock = Minitest::Mock.new
    mock.expect(:write, nil) do |data|
      assert_equal "A"*510 + "\r\n", data
    end
    @irc.instance_variable_set :@sock, mock
    @irc.sendraw "A"*600
    assert_mock mock
  end

  it "logs received messages right" do
    logger = Minitest::Mock.new
    @irc.instance_variable_set :@log, logger

    # no logs for these
    ["375", "372", "376", "PING"].each do |cmd|
      @irc.log_msg(nil, cmd, ["x"], "line")
      assert_mock logger
    end

    # error logs
    ["400", "500", "599"].each do |cmd|
      logger.expect(:error, nil, [String])
      @irc.log_msg(nil, cmd, ["x"], "line")
      assert_mock logger
    end

    # debug logs
    ["399", "600", "123", "FOOBAR"].each do |cmd|
      logger.expect(:debug, nil, [String])
      @irc.log_msg(nil, cmd, ["x"], "line")
      assert_mock logger
    end
  end

end
