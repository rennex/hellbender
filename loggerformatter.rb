
class LoggerFormatter
  COLORS = {
    "DEBUG" => 36,  # cyan
    "INFO"  => 32,  # green
    "WARN"  => 33,  # yellow
    "ERROR" => 31,  # red
    "FATAL" => 35,  # magenta
  }

  def call(severity, datetime, progname, msg)
    time = datetime.strftime("%H:%M:%S.%L")
    # 2m = faint, 22m = normal brightness, 0m = reset style
    "\x1b[#{COLORS[severity] || 0};2m#{time} \x1b[22m#{msg}\x1b[0m\n"
  end
end
