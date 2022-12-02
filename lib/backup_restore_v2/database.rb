# frozen_string_literal: true

module BackupRestoreV2
  DatabaseConfiguration = Struct.new(:host, :port, :username, :password, :database)

  module Database
    MAIN_SCHEMA = "public"

    def self.database_configuration
      config = ActiveRecord::Base.connection_pool.db_config.configuration_hash
      config = config.with_indifferent_access

      # credentials for PostgreSQL in CI environment
      if Rails.env.test?
        username = ENV["PGUSER"]
        password = ENV["PGPASSWORD"]
      end

      DatabaseConfiguration.new(
        config["backup_host"] || config["host"],
        config["backup_port"] || config["port"],
        config["username"] || username || ENV["USER"] || "postgres",
        config["password"] || password,
        config["database"],
      )
    end

    def self.core_migration_files
      files = Dir[Rails.root.join(Discourse::DB_POST_MIGRATE_PATH, "*.rb")]

      ActiveRecord::Migrator.migrations_paths.each do |path|
        files.concat(Dir[Rails.root.join(path, "*.rb")])
      end

      files
    end

    def self.current_core_migration_version
      current_migration_version(core_migration_files)
    end

    def self.current_plugin_migration_version(plugin)
      current_migration_version(plugin_migration_files(plugin))
    end

    private_class_method def self.plugin_migration_files(plugin)
      plugin_root = plugin.directory
      files = Dir[File.join(plugin_root, "/db/migrate/*.rb")]
      files.concat(Dir[File.join(plugin_root, Discourse::DB_POST_MIGRATE_PATH, "*.rb")])
      files
    end

    private_class_method def self.current_migration_version(migration_files)
      return 0 if !ActiveRecord::SchemaMigration.table_exists?

      migration_versions =
        migration_files.map do |path|
          filename = File.basename(path)
          filename[/^\d+/]&.to_i || 0
        end

      db_versions = ActiveRecord::SchemaMigration.all_versions.map(&:to_i)
      migration_versions.intersection(db_versions).max || 0
    end
  end
end
