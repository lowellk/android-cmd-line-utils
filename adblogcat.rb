#!/usr/bin/env ruby

require 'rubygems'
require 'pty'

# tty colors
BLACK = 30
RED = 31
GREEN = 32
YELLOW = 33
BLUE = 34
MAGENTA = 35
CYAN = 36
WHITE = 37

# tty formats
NONE = 0
BOLD = 1
UNDERSCORE = 4

# output of ps on phone
PID_COLUMN = 1
NAME_COLUMN = 8

# 'brief' log format
LOG_FORMAT = /^\w\/\S+\s*\(\s*(\d+)\):/

def escape n
  "\033[#{n}m" if STDOUT.tty?
end

def reset
  escape(0)
end

def printline(line, color, format)
  style = escape("#{format};#{color}")
  puts "#{style}#{line.chomp}#{reset}"
end

def colorize(line)
  color, format = case line[0]
                    when 'V', 'D', 'I'
                      [WHITE, NONE]
                    when 'W'
                      [RED, NONE]
                    when 'E', 'F'
                      [RED, BOLD]
                    else
                      raise "Don't know how to process line: #{line}"
                  end
  if color
    printline(line, color, format)
  end
end

def error(msg)
  puts msg
  exit 1
end

def usage
  error("Usage: #{$0} packageName [logcatOptions]")
end


def get_pid(package_name)
  output = `adb shell ps`.split("\r\n")

  output.shift # header row

  output.each do |line|
    toks = line.split(/\s+/)
    name = toks[NAME_COLUMN]
    pid = toks[PID_COLUMN]
    return pid if name == package_name
  end
  nil
end

def main
  package_name = ARGV.shift or usage

  app_pid = get_pid(package_name)

  unless app_pid
    error("Unable to find running process with package named: #{package_name}")
  end

  # TODO: this won't work if an argument has a space in it. Can that happen?
  cmd = "adb logcat -v brief #{ARGV.join(' ')}"

  PTY.spawn(cmd) do |stdin, stdout, pid|
    stdin.lines.each do |line|
      line =~ LOG_FORMAT
      colorize(line) if app_pid == Regexp.last_match(1)
    end
  end
end

main
