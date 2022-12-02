# frozen_string_literal: true

require "rails_helper"

describe BackupRestoreV2::Database do
  def absolute_path(path)
    Rails.root.join(path).to_s
  end

  describe ".database_configuration" do
    it "returns a DatabaseConfiguration" do
      expect(described_class.database_configuration).to be_a(BackupRestoreV2::DatabaseConfiguration)
    end
  end

  describe ".core_migration_files" do
    it "returns regular and post_migrate migrations" do
      files = described_class.core_migration_files
      expect(files).to include(absolute_path("db/migrate/20120311201341_create_forums.rb"))
      expect(files).to include(
        absolute_path(
          "db/post_migrate/20210528003603_fix_badge_image_avatar_upload_security_and_acls.rb",
        ),
      )
    end

    it "doesn't returns plugin migrations" do
      files = described_class.core_migration_files
      expect(files).to_not include(
        absolute_path("plugins/poll/db/migrate/20180820073549_create_polls_tables.rb"),
      )
    end
  end

  describe ".current_core_migration_version" do
    it "returns 0 if there are no schema migrations" do
      ActiveRecord::SchemaMigration.stubs(:table_exists?).returns(false)
      expect(described_class.current_core_migration_version).to eq(0)
    end

    it "returns the max schema migration version" do
      ActiveRecord::SchemaMigration.where("version > '20130213203300'").delete_all
      expect(described_class.current_core_migration_version).to eq(20_130_213_203_300)
    end

    it "returns the max schema migration version from a post migration" do
      ActiveRecord::SchemaMigration.where("version > '20211201221028'").delete_all
      expect(described_class.current_core_migration_version).to eq(20_211_201_221_028)
    end

    it "doesn't return version numbers from plugins" do
      ActiveRecord::SchemaMigration.where("version > '20180820073549'").delete_all

      # Make sure that the migration from the poll plugin exists.
      # It might be missing if the DB was migrated without plugin migrations.
      if !ActiveRecord::SchemaMigration.where(version: "20180820073549").exists?
        ActiveRecord::SchemaMigration.create!(version: "20180820073549")
      end

      expect(described_class.current_core_migration_version).to eq(20_180_813_074_843)
    end
  end

  describe ".current_plugin_migration_version" do
    let(:plugin) do
      metadata = Plugin::Metadata.new
      metadata.name = "poll"
      Plugin::Instance.new(metadata, absolute_path("plugins/poll/plugin.rb"))
    end

    it "returns 0 if there are no schema migrations" do
      ActiveRecord::SchemaMigration.stubs(:table_exists?).returns(false)
      expect(described_class.current_plugin_migration_version(plugin)).to eq(0)
    end

    it "returns the max schema migration version" do
      ActiveRecord::SchemaMigration.where("version > '20220101010000'").delete_all

      # Make sure that the migration from the poll plugin exists.
      # It might be missing if the DB was migrated without plugin migrations.
      if !ActiveRecord::SchemaMigration.where(version: "20200804144550").exists?
        ActiveRecord::SchemaMigration.create!(version: "20200804144550")
      end

      expect(described_class.current_plugin_migration_version(plugin)).to eq(20_200_804_144_550)
    end
  end
end
