
require "readline"

module Hellbender

  class REPL
    def self.launch(bot)
      Thread.new {
        self.new(bot).run
      }
    end

    def initialize(bot)
      @bot = bot
    end

    def run
      loop do
        process_line
      end
    end

    def process_line
      line = Readline.readline("\e[1Gruby> ", true)
      if line
        line.strip!
        return if line.empty?

        result = @bot.instance_eval(line)

        puts "=> \e[1m" + result.inspect + "\e[0m"
      end

    rescue SystemExit
      raise

    rescue Exception => e
      @bot.log.error "#{e.class}: #{e.message}"
    end

  end

end
