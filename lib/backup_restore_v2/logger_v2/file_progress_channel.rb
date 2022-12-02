# frozen_string_literal: true

require "colored2"
require "ruby-progressbar"

module BackupRestoreV2
  class LoggerV2
    class FileProgressChannel
      MIN_SECONDS_BETWEEN_PROGRESS_LOGGING = 60

      def initialize(message, logger)
        @message = message
        @logger = logger
      end

      def start(max_progress)
        @progress = 0
        @max_progress = max_progress

        @logger.info("#{@message}... 0 / #{@max_progress}")

        @last_output_time = clock_time
        @last_output_percent = 0
      end

      def increment
        @progress += 1

        progress_percent = @progress * 100 / @max_progress
        current_time = clock_time

        if loggable?(progress_percent, current_time)
          @last_output_time = current_time
          @last_output_percent = progress_percent

          @logger.info("#{@message}... #{@progress} / #{@max_progress} | #{progress_percent}%")
        end
      end

      def success
        @logger.info("#{@message}... done!")
      end

      def error
        @logger.error("#{@message}... failed!")
      end

      private def clock_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      private def loggable?(progress_percent, current_time)
        progress_percent > @last_output_percent &&
          current_time - @last_output_time > MIN_SECONDS_BETWEEN_PROGRESS_LOGGING
      end
    end
  end
end
