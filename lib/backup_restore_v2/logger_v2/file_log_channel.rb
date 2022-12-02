# frozen_string_literal: true

module BackupRestoreV2
  class LoggerV2
    class FileLogChannel
      def initialize(file)
        @logger = ::Logger.new(file, formatter: LogFormatter.new.method(:call))
      end

      def log(severity, message, exception = nil)
        @logger.log(severity, message)
        @logger.log(severity, exception) if exception
      end

      def trigger_event(message)
      end

      def start_step(severity, message)
        @logger.log(severity, "#{message}...")
      end

      def stop_step(severity, message)
        @logger.log(severity, "#{message}... done")
      end

      def close
        @logger.close
      end

      def create_progress_channel(message)
        FileProgressChannel.new(message, @logger)
      end

      class LogFormatter < ::Logger::Formatter
        FORMAT = "[%s] %5s -- %s\n"

        def initialize
          super
        end

        def call(severity, time, progname, msg)
          FORMAT % [format_datetime(time), severity, msg2str(msg)]
        end

        def format_datetime(time)
          time.utc.iso8601(4)
        end
      end
    end
  end
end
