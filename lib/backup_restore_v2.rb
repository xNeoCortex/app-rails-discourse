# frozen_string_literal: true

module BackupRestoreV2
  FILE_FORMAT = 2
  DUMP_FILE = "dump.sql.gz"
  UPLOADS_FILE = "uploads.tar.gz"
  OPTIMIZED_IMAGES_FILE = "optimized-images.tar.gz"
  METADATA_FILE = "meta.json"
  LOGS_CHANNEL = "/admin/backups/logs"

  def self.backup!(user_id, opts = {})
    if opts[:fork] == false
      logger =
        if opts[:cli] == true
          BackupRestoreV2::Logger::CliLogger.new("backup")
        else
          BackupRestoreV2::Logger::DefaultLogger.new(user_id, opts[:client_id], "backup")
        end
      BackupRestoreV2::Backuper.new(user_id, logger).run
    else
      spawn_process("backup_v2", user_id, opts)
    end
  end

  private_class_method def self.spawn_process(type, user_id, opts)
    script = File.join(Rails.root, "script", "spawn_backup_restore.rb")
    command = ["bundle", "exec", "ruby", script, type, user_id, opts.to_json].map(&:to_s)

    pid = spawn({ "RAILS_DB" => RailsMultisite::ConnectionManagement.current_db }, *command)
    Process.detach(pid)
  end
end
