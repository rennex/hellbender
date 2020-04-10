require "minitest/autorun"
require "minitest/pride"

# used in bot_test.rb and plugin_test.rb
def create_test_bot(config = {"server" => {"nick" => "Hellbender"}})
  bot = Hellbender::Bot.new(config)
  bot.log.level = Logger::FATAL
  class << bot
    def process_msg(*args)
      # wait for all the subscribers to finish running
      super.each(&:join)
    end
  end
  return bot
end
