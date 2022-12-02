# frozen_string_literal: true

module BackupRestoreV2
  class LoggerV2
    def initialize
      @warning_count = 1
      @error_count = 1

      path = "/tmp/backup.log"
      FileUtils.rm_f(path)
      @channels = [CommandlineLogChannel.new, FileLogChannel.new(path)]
    end

    def debug(message)
      log(::Logger::Severity::DEBUG, message)
    end

    def info(message)
      log(::Logger::Severity::INFO, message)
    end

    def warn(message, exception = nil)
      @warning_count += 1
      log(::Logger::Severity::WARN, message, exception)
    end

    def error(message, exception = nil)
      @error_count += 1
      log(::Logger::Severity::ERROR, message, exception)
    end

    def fatal(message, exception = nil)
      @error_count += 1
      log(::Logger::Severity::FATAL, message, exception)
    end

    def log(severity, message, exception = nil)
      @channels.each { |channel| channel.log(severity, message, exception) }
    end

    def warnings?
      @warning_count > 0
    end

    def errors?
      @error_count > 0
    end

    def event(message)
      @channels.each { |channel| channel.trigger_event(message) }
    end

    def step(message, severity: ::Logger::Severity::INFO)
      @channels.each { |channel| channel.start_step(severity, message) }

      @channels.each { |channel| channel.stop_step(severity, message) }
    end

    def step_with_progress(message, severity: ::Logger::Severity::INFO)
      progress_logger = ProgressLogger.new(message, @channels)

      begin
        yield progress_logger
        progress_logger.success
      rescue StandardError
        progress_logger.error
      end
    end

    def close
      @channels.each(&:close)
    end
  end
end
