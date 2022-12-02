# frozen_string_literal: true

require "thor"

module DiscourseCLI
  class BackupCommand < Thor
    desc "create", "Creates a backup"
    def create
      DiscourseCLI.load_rails

      with_logger("backup") do |logger|
        backuper = BackupRestoreV2::Backuper.new(Discourse::SYSTEM_USER_ID, logger)
        backuper.run
        exit(1) unless backuper.success
      end
    end

    desc "restore FILENAME", "Restores a backup"
    def restore(filename)
    end

    desc "list", "Lists existing backups"
    def list
    end

    desc "delete", "Deletes a backup"
    def delete
    end

    desc "download", "Downloads a backup"
    def download
    end

    desc "test", "Testing stuff"
    def test
      DiscourseCLI.load_rails

      logger = BackupRestoreV2::LoggerV2.new
      logger.debug("Hello world")
      logger.info("Hello world")
      logger.warn("Hello world")
      logger.error("Hello world")
      logger.fatal("Hello world")

      logger.step_with_progress("Preparing rocket") do |progress|
        max = 1000
        progress.start(max)
        (1..max).each do |i|
          sleep(0.01)
          progress.increment
          sleep(2) if i == max
        end
      end

      logger.close
    end

    no_commands do
      private def with_logger(name)
        logger = BackupRestoreV2::Logger::CliLogger.new(name)
        yield logger
      ensure
        logger.close if logger
      end
    end
  end
end
