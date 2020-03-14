require "minitest/autorun"

require_relative "../bot.rb"

describe Hellbender::Bot do
  before do
    @bot = Hellbender::Bot.new({"server" => {"nick" => "Hellbender"}})
    @bot.log.level = Logger::FATAL
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



end
