# frozen_string_literal: true

require "colored2"
require "ruby-progressbar"

module BackupRestoreV2
  class LoggerV2
    class CommandlineProgressChannel
      FORMAT_WITHOUT_PERCENTAGE = "%t | %c / %C | %E"
      FORMAT_WITH_PERCENTAGE = " %j%%  #{FORMAT_WITHOUT_PERCENTAGE}"

      def initialize(message)
        @message = message

        # see https://github.com/jfelchner/ruby-progressbar/wiki/Formatting
        @progressbar =
          ::ProgressBar.create(
            format: FORMAT_WITH_PERCENTAGE,
            title: @message,
            autofinish: false,
            smoothing: 0.5,
            time: ProgressBarClockTime.new,
          )
      end

      def start(max_progress)
        @max_progress = max_progress

        @progressbar.progress = 0
        @progressbar.total = @max_progress
      end

      def increment
        @progressbar.increment
      end

      def success
        reset_current_line
        @progressbar.format = FORMAT_WITHOUT_PERCENTAGE
        @progressbar.title = " DONE".green + "  #{@message}"
        @progressbar.finish
      end

      def error
        reset_current_line
        @progressbar.format = FORMAT_WITHOUT_PERCENTAGE
        @progressbar.title = " FAIL".red + "  #{@message}"
        @progressbar.finish
      end

      # delete the output of progressbar, because it doesn't overwrite longer lines
      private def reset_current_line
        print "\033[K"
      end

      class ProgressBarClockTime
        # make the time calculations more accurate
        # see https://blog.dnsimple.com/2018/03/elapsed-time-with-ruby-the-right-way/
        def now
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end
      end
    end
  end
end
