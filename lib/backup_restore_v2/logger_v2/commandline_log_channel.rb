# frozen_string_literal: true

require "colored2"

module BackupRestoreV2
  class LoggerV2
    class CommandlineLogChannel
      def initialize
        @logger = ColorfulLoggger.new(STDOUT, formatter: LogFormatter.new.method(:call))
      end

      def log(severity, message, exception = nil)
        @logger.log(severity, message)
        @logger.log(severity, exception) if exception
      end

      def trigger_event(message)
      end

      def start_step(severity, message)
      end

      def stop_step(severity, message)
      end

      def close
        @logger.close
      end

      def create_progress_channel(message)
        CommandlineProgressChannel.new(message)
      end

      class ColorfulLoggger < ::Logger
        SEVERITY_LABELS = [
          "DEBUG",
          " INFO".blue,
          " WARN".yellow,
          "ERROR".red,
          "FATAL".red,
          "  ANY",
        ].freeze

        private def format_severity(severity)
          SEVERITY_LABELS[severity]
        end
      end

      class LogFormatter < ::Logger::Formatter
        def call(severity, time, progname, msg)
          "#{severity}  #{msg2str(msg)}\n"
        end

        def format_datetime(time)
          time.utc.iso8601(4)
        end
      end
    end
  end
end
