
require_relative "bot"
require_relative "plugin"
require_relative "repl"


class TopicComplainer
  include Hellbender::Plugin

  def initialize(pongreply = "pong")
    @pongreply = pongreply
  end

  subscribe("TOPIC") do |m|
    m.channel.msg "#{m.user}: quit changing the topic"
  end

  react /^ping$/i, :ping
  def ping(m)
    m.reply @pongreply
  end
end


class Calculator
  include Hellbender::Plugin

  command "calc", method: \
  def calculate(m)
    if m.text =~ %r{^[-+*/0-9. ()]+$}
      begin
        if m.text.index("(")
          m.reply "Computing..."
          sleep 3
        end
        m.reply eval(m.text), nick: true

      rescue RuntimeError, SyntaxError => e
        m.reply "Error: #{e.class}: #{e}"
      end

    elsif m.text == ""
      m.reply rand(10000), nick: true
    end
  end
end


config = YAML.load(File.open("config.yml"))
begin
  bot = Hellbender::Bot.new(config)

  bot.subscribe("INVITE") do |m|
    if m.channel =~ /^#hellbender-dev$/i
      m.channel.join
    end
  end

  bot.plugin TopicComplainer.new("p0ngerz")
  bot.plugin Calculator

  # run a REPL on stdin
  Hellbender::REPL.launch(bot)

  bot.run

rescue Interrupt, SystemExit
  STDERR.puts "\nQuitting"
end
