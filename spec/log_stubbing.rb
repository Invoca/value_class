# frozen_string_literal: true

require "exception_handling"

class TestLog
  def self.stream
    @log_stream ||= StringIO.new
  end

  def self.logged_lines
    @log_stream.rewind
    lines = @log_stream.readlines
    clear_log
    lines.map { |l| l.strip }.reject { |l| l == "" }.compact
  end

  def self.clear_log
    @log_stream.reopen
  end
end

# required
ExceptionHandling.server_name             = "test"
ExceptionHandling.sender_address          = %("Exceptions" <exceptions@example.com>)
ExceptionHandling.exception_recipients    = ['exceptions@example.com']
ExceptionHandling.logger                  = Logger.new(TestLog.stream)



module Rails
  def self.env
    'test'
  end
end
