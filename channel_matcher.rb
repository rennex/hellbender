
require_relative "util"
require_relative "target"

module Hellbender
  class ChannelMatcher
    def initialize(include: nil, exclude: nil)
      @include = parse_arg(include)
      @exclude = parse_arg(exclude)
    end

    def parse_arg(channels)
      Array(channels).map do |chan|
        case chan
        when String
          Channel.new(chan)
        else
          chan
        end
      end
    end

    def match?(channel)
      # this is needed for Regexps, but unnecessary for Channels
      channel = Util::irccase(channel)

      return false if @exclude.include?(:all)
      @exclude.each do |c|
        return false if c === channel
      end

      return true if @include.empty? || @include.include?(:all)
      @include.each do |c|
        return true if c === channel
      end

      return false
    end

    alias === match?

  end
end
