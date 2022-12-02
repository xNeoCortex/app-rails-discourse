# frozen_string_literal: true

require "rails_helper"

describe BackupRestoreV2::Backuper do
  fab!(:admin) { Fabricate(:admin) }
  let!(:logger) do
    Class
      .new(BackupRestoreV2::Logger::BaseLogger) do
        def log(message, level: nil)
          @logs << message
        end

        def log_event(event)
          @logs << event
        end
      end
      .new
  end

  subject { described_class.new(admin.id, logger) }

  def execute_failed_backup
    BackupRestoreV2::Operation.stubs(:start).raises(BackupRestoreV2::OperationRunningError)
    subject.run
  end

  def execute_successful_backup(site_name: "discourse")
    freeze_time(Time.parse("2021-03-24T20:27:31Z"))

    tar_writer = mock("tar_writer")
    expect_tar_creation(tar_writer, site_name)
    expect_db_dump_added_to_tar(tar_writer)
    expect_uploads_added_to_tar(tar_writer)
    expect_optimized_images_added_to_tar(tar_writer)
    expect_metadata_added_to_tar(tar_writer)

    subject.run
  end

  def expect_tar_creation(tar_writer, site_name)
    current_db = RailsMultisite::ConnectionManagement.current_db
    filename =
      File.join(Rails.root, "public", "backups", current_db, "#{site_name}-2021-03-24T202731Z.tar")

    MiniTarball::Writer.expects(:create).with(filename).yields(tar_writer).once
  end

  def expect_db_dump_added_to_tar(tar_writer)
    output_stream = mock("db_dump_output_stream")

    BackupRestoreV2::Backup::DatabaseDumper
      .any_instance
      .expects(:dump_schema_into)
      .with(output_stream)
      .once

    tar_writer
      .expects(:add_file_from_stream)
      .with(has_entry(name: "dump.sql.gz"))
      .yields(output_stream)
      .once
  end

  def expect_uploads_added_to_tar(tar_writer)
    output_stream = mock("uploads_stream")

    BackupRestoreV2::Backup::UploadBackuper
      .any_instance
      .expects(:compress_uploads_into)
      .with(output_stream)
      .returns(BackupRestoreV2::Backup::UploadStats.new(total_count: 42))
      .once

    BackupRestoreV2::Backup::UploadBackuper.expects(:include_uploads?).returns(true).once

    tar_writer
      .expects(:add_file_from_stream)
      .with(has_entry(name: "uploads.tar.gz"))
      .yields(output_stream)
      .once
  end

  def expect_optimized_images_added_to_tar(tar_writer)
    output_stream = mock("optimized_images_stream")

    BackupRestoreV2::Backup::UploadBackuper
      .any_instance
      .expects(:compress_optimized_images_into)
      .with(output_stream)
      .returns(BackupRestoreV2::Backup::UploadStats.new(total_count: 42))
      .once

    BackupRestoreV2::Backup::UploadBackuper.expects(:include_optimized_images?).returns(true).once

    tar_writer
      .expects(:add_file_from_stream)
      .with(has_entry(name: "optimized-images.tar.gz"))
      .yields(output_stream)
      .once
  end

  def expect_metadata_added_to_tar(tar_writer)
    output_stream = mock("metadata_stream")

    BackupRestoreV2::Backup::MetadataWriter
      .any_instance
      .expects(:estimated_file_size)
      .returns(417)
      .once

    BackupRestoreV2::Backup::MetadataWriter
      .any_instance
      .expects(:write_into)
      .with(output_stream)
      .once

    tar_writer
      .expects(:add_file_placeholder)
      .with(has_entries(name: "meta.json", file_size: 417))
      .returns(1)
      .once

    tar_writer.expects(:with_placeholder).with(1).yields(tar_writer).once

    tar_writer
      .expects(:add_file_from_stream)
      .with(has_entry(name: "meta.json"))
      .yields(output_stream)
      .once
  end

  it "successfully creates a backup" do
    execute_successful_backup
  end

  context "with logging for UI" do
    it "logs events for successful backup" do
      execute_successful_backup

      expect(logger.logs.first).to eq("[STARTED]")
      expect(logger.logs.last).to eq("[SUCCESS]")
    end

    it "logs events for failed backup" do
      execute_failed_backup

      expect(logger.logs.first).to eq("[STARTED]")
      expect(logger.logs.last).to eq("[FAILED]")
    end
  end
end
