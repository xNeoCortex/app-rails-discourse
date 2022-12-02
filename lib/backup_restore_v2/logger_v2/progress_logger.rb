# frozen_string_literal: true

module BackupRestoreV2
  class LoggerV2
    class ProgressLogger
      def initialize(message, channels)
        @channels = channels.map { |c| c.create_progress_channel(message) }.compact
      end

      def start(max_progress)
        @channels.each { |c| c.start(max_progress) }
      end

      def increment
        @channels.each { |c| c.increment }
      end

      def success
        @channels.each { |c| c.success }
      end

      def error
        @channels.each { |c| c.error }
      end
    end
  end
end
