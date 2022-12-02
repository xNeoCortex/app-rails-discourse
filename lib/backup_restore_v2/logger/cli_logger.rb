# frozen_string_literal: true

require "colored2"
require "tty-spinner"

module BackupRestoreV2
  module Logger
    class CliLogger < BaseLogger
      def initialize(operation)
        super()

        timestamp = Time.now.utc.strftime("%Y-%m-%dT%H%M%SZ")
        current_db = RailsMultisite::ConnectionManagement.current_db
        path = File.join(Rails.root, "log", "backups", current_db)
        FileUtils.mkdir_p(path)
        path = File.join(path, "#{operation}-#{timestamp}.log")

        @logfile = File.new(path, "w")
        log_to_stdout("Logging to #{path}")
      end

      def close
        @logfile.close
      end

      def log_step(message, with_progress: false)
        if with_progress
          logger = CliProgressLogger.new(message, self)
          begin
            yield(logger)
            logger.success
          rescue Exception
            logger.error
            raise
          end
        else
          spin(message, abort_on_error: false) { yield }
        end
        nil
      end

      def log(message, level: Logger::INFO)
        log_to_stdout(message, level)
        log_to_logfile(message, level)
      end

      def log_to_stdout(message, level = Logger::INFO)
        case level
        when Logger::INFO
          puts "INFO " + " #{message}"
        when Logger::ERROR
          puts "FAIL ".red + " #{message}"
        when Logger::WARNING
          puts "WARN ".yellow + " #{message}"
        else
          puts message
        end
      end

      def log_to_logfile(message, level = Logger::INFO)
        timestamp = Time.now.utc.iso8601

        case level
        when Logger::INFO
          @logfile.puts("[#{timestamp}] INFO: #{message}")
        when Logger::ERROR
          @logfile.puts("[#{timestamp}] ERROR: #{message}")
        when Logger::WARNING
          @logfile.puts("[#{timestamp}] WARN: #{message}")
        else
          @logfile.puts("[#{timestamp}] #{message}")
        end
      end

      private def spin(title, abort_on_error)
        result = nil

        spinner = abort_on_error ? error_spinner : warning_spinner
        spinner.update(title: title)
        spinner.auto_spin

        begin
          result = yield
          spinner.success
        rescue Exception
          spinner.error
          raise if abort_on_error
        end

        result
      end

      private def error_spinner
        @error_spinner ||= create_spinner(show_warning_instead_of_error: false)
      end

      private def warning_spinner
        @warning_spinner ||= create_spinner(show_warning_instead_of_error: true)
      end

      private def create_spinner(show_warning_instead_of_error:)
        output = $stderr

        if output.tty? && !ENV["RM_INFO"] # special case for RubyMine
          TTY::Spinner.new(
            ":spinner :title",
            success_mark: "DONE ".green,
            error_mark: show_warning_instead_of_error ? "WARN ".yellow : "FAIL ".red,
            interval: 10,
            frames: ["     ", "   = ", "  == ", " === ", "==== ", "===  ", "==   ", "=    "],
          )
        else
          DummySpinner.new(
            success_mark: "DONE".green,
            error_mark: show_warning_instead_of_error ? "WARN".yellow : "FAIL".red,
          )
        end
      end
    end

    # A very simple implementation to make the spinner work when there's no TTY
    class DummySpinner
      def initialize(format: ":title... ", success_mark: "✓", error_mark: "✘")
        @format = format
        @success_mark = success_mark
        @error_mark = error_mark
      end

      def auto_spin
        text = @title ? @format.gsub(":title", @title) : @format
        print(text)
      end

      def update(title:)
        @title = title
      end

      def success
        puts(@success_mark)
      end

      def error
        puts(@error_mark)
      end
    end
  end
end
