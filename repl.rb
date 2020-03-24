
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
      line = Readline.readline("", true)
      return if line.nil?
      line.strip!
      if line.empty?
        Readline::HISTORY.pop
        return
      end

      begin
        result = @bot.instance_eval(line)
      rescue SystemExit
        raise
      rescue Exception => e
        @bot.log.error "#{e.class}: #{e.message}"
      end

      puts "=> \e[1m#{result.inspect}\e[0m"
    end

  end

end
