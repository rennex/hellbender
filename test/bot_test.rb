require "minitest/autorun"

require_relative "../bot.rb"

describe Hellbender::Bot do
  before do
    @bot = Hellbender::Bot.new({"server" => {"nick" => "Hellbender"}})
    @bot.log.level = Logger::FATAL
    class << @bot
      def process_msg(*args)
        # wait for all the subscribers to finish running
        super.each(&:join)
      end
    end
  end

  it "tracks its own nickname" do
    assert_equal "Hellbender", @bot.nick
    @bot.process_msg("Hellbender", "NICK", ["bot"])
    assert_equal "bot", @bot.nick.to_s
  end

  it "tracks its own channels" do
    assert_equal [], @bot.channels
    @bot.process_msg("Hellbender", "JOIN", ["#chan"])
    @bot.process_msg("Hellbender", "JOIN", ["#foo"])
    assert_equal [Channel["#chan"], Channel["#foo"]], @bot.channels.sort

    @bot.process_msg("some!one@x", "KICK", ["#foo", "Hellbender", "go away"])
    assert_equal [Channel["#chan"]], @bot.channels

    @bot.process_msg("Hellbender", "PART", ["#chan", "bye"])
    assert_equal [], @bot.channels
  end

  it "supports subscribing to messages" do
    all_count = 0
    @bot.subscribe(:all) {
      all_count += 1
    }

    join_part_count = 0
    @bot.subscribe(["JOIN", "PART"]) {
      join_part_count += 1
    }

    msg_count = 0
    msg_from = msg_text = nil
    @bot.subscribe("PRIVMSG") {|m|
      msg_count += 1
      msg_from = m.user
      msg_text = m.text
    }

    @bot.process_msg("u", "FOOBAR", [])
    @bot.process_msg("u", "JOIN", ["#chan"])
    @bot.process_msg("u", "PRIVMSG", ["#chan", "hello"])
    @bot.process_msg("u", "PART", ["#chan"])

    assert_equal 4, all_count
    assert_equal 2, join_part_count
    assert_equal 1, msg_count
    assert_equal "u", msg_from.to_s
    assert_equal "hello", msg_text
  end
end
