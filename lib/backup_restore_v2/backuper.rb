# frozen_string_literal: true

require "etc"
require "mini_tarball"

module BackupRestoreV2
  class Backuper
    delegate :log, :log_event, :log_step, :log_warning, :log_error, to: :@logger, private: true
    attr_reader :success

    # @param [Hash] opts
    # @option opts [String] :backup_path_override
    # @option opts [String] :ticket
    def initialize(user_id, logger, opts = {})
      @user = User.find_by(id: user_id) || Discourse.system_user
      @logger = logger
      @opts = opts
    end

    def run
      log_event "[STARTED]"
      log "User '#{@user.username}' started backup"

      initialize_backup
      create_backup
      upload_backup
      finalize_backup

      @success = true
      @backup_path
    rescue SystemExit, SignalException
      log_warning "Backup operation was canceled!"
    rescue BackupRestoreV2::OperationRunningError
      log_error "Operation is already running"
    ensure
      clean_up
      notify_user
      complete
    end

    private

    def initialize_backup
      log_step("Initializing backup") do
        @success = false
        @store = BackupRestore::BackupStore.create

        BackupRestoreV2::Operation.start

        timestamp = Time.now.utc.strftime("%Y-%m-%dT%H%M%SZ")
        current_db = RailsMultisite::ConnectionManagement.current_db
        archive_directory_override, filename_override = calculate_path_overrides
        archive_directory =
          archive_directory_override ||
            BackupRestore::LocalBackupStore.base_directory(db: current_db)

        filename =
          filename_override ||
            begin
              parameterized_title = SiteSetting.title.parameterize.presence || "discourse"
              "#{parameterized_title}-#{timestamp}"
            end

        @backup_filename = "#{filename}.tar"
        @backup_path = File.join(archive_directory, @backup_filename)
        @tmp_directory = File.join(Rails.root, "tmp", "backups", current_db, timestamp)

        FileUtils.mkdir_p(archive_directory)
        FileUtils.mkdir_p(@tmp_directory)
      end
    end

    def create_backup
      metadata_writer = BackupRestoreV2::Backup::MetadataWriter.new

      MiniTarball::Writer.create(@backup_path) do |tar_writer|
        metadata_placeholder = add_metadata_placeholder(tar_writer, metadata_writer)
        add_db_dump(tar_writer)
        metadata_writer.upload_stats = add_uploads(tar_writer)
        metadata_writer.optimized_image_stats = add_optimized_images(tar_writer)
        add_metadata(tar_writer, metadata_writer, metadata_placeholder)
      end
    end

    # Adds an empty file to the backup archive which acts as a placeholder for the `meta.json` file.
    # This file needs to be the first file in the backup archive in order to allow reading the backup's
    # metadata without downloading the whole file. The file size is estimated because some of the data
    # is still unknown at this time.
    # @param [MiniTarball::Writer] tar_writer
    # @param [BackupRestoreV2::Backup::MetadataWriter] metadata_writer
    # @return [Integer] index of the placeholder
    def add_metadata_placeholder(tar_writer, metadata_writer)
      tar_writer.add_file_placeholder(
        name: BackupRestoreV2::METADATA_FILE,
        file_size: metadata_writer.estimated_file_size,
      )
    end

    # Streams the database dump directly into the backup archive.
    # @param [MiniTarball::Writer] tar_writer
    def add_db_dump(tar_writer)
      log_step("Creating database dump") do
        tar_writer.add_file_from_stream(
          name: BackupRestoreV2::DUMP_FILE,
          **tar_file_attributes,
        ) do |output_stream|
          dumper = Backup::DatabaseDumper.new
          dumper.dump_schema_into(output_stream)
        end
      end
    end

    # Streams uploaded files directly into the backup archive.
    # @param [MiniTarball::Writer] tar_writer
    def add_uploads(tar_writer)
      if skip_uploads? || !Backup::UploadBackuper.include_uploads?
        log "Skipping uploads"
        return
      end

      stats = nil

      log_step("Adding uploads", with_progress: true) do |progress_logger|
        tar_writer.add_file_from_stream(
          name: BackupRestoreV2::UPLOADS_FILE,
          **tar_file_attributes,
        ) do |output_stream|
          backuper = Backup::UploadBackuper.new(@tmp_directory, progress_logger)
          stats = backuper.compress_uploads_into(output_stream)
        end
      end

      if stats && stats.missing_count > 0
        log_warning "Failed to add #{stats.missing_count} uploads. See logfile for details."
      end

      stats
    end

    # Streams optimized images directly into the backup archive.
    # @param [MiniTarball::Writer] tar_writer
    def add_optimized_images(tar_writer)
      if skip_uploads? || !Backup::UploadBackuper.include_optimized_images?
        log "Skipping optimized images"
        return
      end

      stats = nil

      log_step("Adding optimized images", with_progress: true) do |progress_logger|
        tar_writer.add_file_from_stream(
          name: BackupRestoreV2::OPTIMIZED_IMAGES_FILE,
          **tar_file_attributes,
        ) do |output_stream|
          backuper = Backup::UploadBackuper.new(@tmp_directory, progress_logger)
          stats = backuper.compress_optimized_images_into(output_stream)
        end
      end

      if stats && stats.missing_count > 0
        log_warning "Failed to add #{stats.missing_count} optimized images. See logfile for details."
      end

      stats
    end

    # Overwrites the `meta.json` file at the beginning of the backup archive.
    # @param [MiniTarball::Writer] tar_writer
    # @param [BackupRestoreV2::Backup::MetadataWriter] metadata_writer
    # @param [Integer] placeholder index of the placeholder
    def add_metadata(tar_writer, metadata_writer, placeholder)
      log_step("Adding metadata file") do
        tar_writer.with_placeholder(placeholder) do |writer|
          writer.add_file_from_stream(
            name: BackupRestoreV2::METADATA_FILE,
            **tar_file_attributes,
          ) { |output_stream| metadata_writer.write_into(output_stream) }
        end
      end
    end

    def upload_backup
      return unless @store.remote?

      file_size = File.size(@backup_path)
      file_size =
        Object.new.extend(ActionView::Helpers::NumberHelper).number_to_human_size(file_size)

      log_step("Uploading backup (#{file_size})") do
        @store.upload_file(@backup_filename, @backup_path, "application/x-tar")
      end
    end

    def finalize_backup
      log_step("Finalizing backup") { DiscourseEvent.trigger(:backup_created) }
    end

    def clean_up
      log_step("Cleaning up") do
        # delete backup if there was an error or the file was uploaded to a remote store
        if @backup_path && File.exist?(@backup_path) && (!@success || @store.remote?)
          File.delete(@backup_path)
        end

        # delete the temp directory
        FileUtils.rm_rf(@tmp_directory) if @tmp_directory && Dir.exist?(@tmp_directory)

        if Rails.env.development?
          @store&.reset_cache
        else
          @store&.delete_old
        end
      end
    end

    def notify_user
      return if @success && @user.id == Discourse::SYSTEM_USER_ID

      log_step("Notifying user") do
        status = @success ? :backup_succeeded : :backup_failed
        logs = Discourse::Utils.logs_markdown(@logger.logs, user: @user)
        post = SystemMessage.create_from_system_user(@user, status, logs: logs)

        post.topic.invite_group(@user, Group[:admins]) if @user.id == Discourse::SYSTEM_USER_ID
      end
    end

    def complete
      begin
        BackupRestoreV2::Operation.finish
      rescue => e
        log_error "Failed to mark operation as finished", e
      end

      if @success
        if @store.remote?
          location = BackupLocationSiteSetting.find_by_value(SiteSetting.backup_location)
          location = I18n.t("admin_js.#{location[:name]}") if location
          log "Backup stored on #{location} as #{@backup_filename}"
        else
          log "Backup stored at: #{@backup_path}"
        end

        if @logger.warnings?
          log_warning "Backup completed with warnings!"
        else
          log "Backup completed successfully!"
        end

        log_event "[SUCCESS]"
        DiscourseEvent.trigger(:backup_complete, logs: @logger.logs, ticket: @opts[:ticket])
      else
        log_error "Backup failed!"
        log_event "[FAILED]"
        DiscourseEvent.trigger(:backup_failed, logs: @logger.logs, ticket: @opts[:ticket])
      end
    end

    def tar_file_attributes
      @tar_file_attributes ||= {
        uid: Process.uid,
        gid: Process.gid,
        uname: Etc.getpwuid(Process.uid).name,
        gname: Etc.getgrgid(Process.gid).name,
      }
    end

    def calculate_path_overrides
      backup_path_override = @opts[:backup_path_override]

      if @opts[:backup_path_override].present?
        archive_directory_override = File.dirname(backup_path_override).sub(/^\.$/, "")

        if archive_directory_override.present? && @store.remote?
          log_warning "Only local backup storage supports overriding backup path."
          archive_directory_override = nil
        end

        filename_override =
          File.basename(backup_path_override).sub(/\.(sql\.gz|tar|tar\.gz|tgz)$/i, "")
        [archive_directory_override, filename_override]
      end
    end

    def skip_uploads?
      !@opts.fetch(:with_uploads, true)
    end
  end
end
