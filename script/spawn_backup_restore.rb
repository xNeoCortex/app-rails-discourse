# frozen_string_literal: true
# This script is used by BackupRestore.backup! and BackupRestore.restore!

fork do
  require File.expand_path("../../config/environment", __FILE__)

  def backup
    user_id, opts = parse_params
    BackupRestore::Backuper.new(user_id, opts).run
  end

  def restore
    user_id, opts = parse_params

    BackupRestore::Restorer.new(
      user_id: user_id,
      filename: opts[:filename],
      factory: BackupRestore::Factory.new(user_id: user_id, client_id: opts[:client_id]),
      disable_emails: opts.fetch(:disable_emails, true),
    ).run
  end

  def backup_v2
    user_id, opts = parse_params
    logger = BackupRestoreV2::Logger::DefaultLogger.new(user_id, opts[:client_id], "backup")
    backuper = BackupRestoreV2::Backuper.new(user_id, logger, opts)
    backuper.run
  end

  def parse_params
    user_id = ARGV[1].to_i
    opts = JSON.parse(ARGV[2], symbolize_names: true)
    [user_id, opts]
  end

  case ARGV[0]
  when "backup"
    backup
  when "restore"
    restore
  when "backup_v2"
    backup_v2
  else
    raise "Unknown argument: #{ARGV[0]}"
  end
end
