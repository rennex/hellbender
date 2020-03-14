
require_relative "bot"
require_relative "repl"

config = YAML.load(File.open("config.yml"))
begin
  bot = Hellbender::Bot.new(config)

  bot.subscribe("TOPIC") do |m|
    m.channel.msg "#{m.user}: quit changing the topic"
  end


  # run a REPL on stdin
  Hellbender::REPL.launch(bot)

  bot.run

rescue Interrupt, SystemExit
  STDERR.puts "\nQuitting"
end
