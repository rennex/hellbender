
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
      # we use this binding so that local variables can be set in the repl
      # (note that this has to be a string; a block behaves differently)
      @binding = bot.instance_eval "binding"
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
        # take empty lines out of the history
        Readline::HISTORY.pop
        return
      end

      begin
        result = @binding.eval(line)
      rescue SystemExit
        raise
      rescue Exception => e
        @bot.log.error "#{e.class}: #{e.message}"
      end

      puts "=> \e[1m#{result.inspect}\e[0m"
    end

  end

end
