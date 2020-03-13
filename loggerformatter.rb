
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
    # 1G = go to column 1, 2m = faint, 22m = normal brightness, 0m = reset style
    "\e[1G\e[#{COLORS[severity] || 0};2m#{time} \e[22m#{msg}\e[0m\n"
  end
end
