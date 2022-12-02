# frozen_string_literal: true

require "json"

module BackupRestoreV2
  module Backup
    class MetadataWriter
      attr_accessor :upload_stats, :optimized_image_stats

      def initialize(uploads_stats = nil, optimized_images_stats = nil)
        @upload_stats = uploads_stats
        @optimized_image_stats = optimized_images_stats
      end

      def write_into(output_stream)
        output_stream.write(json)
      end

      def estimated_file_size
        # adding an additional KB to account for unknown upload stats
        json.bytesize + 1.kilobyte
      end

      private

      def json
        @cached_data ||= {
          backup_format: FILE_FORMAT,
          discourse_version: Discourse::VERSION::STRING,
          db_version: Database.current_core_migration_version,
          git_version: Discourse.git_version,
          git_branch: Discourse.git_branch,
          base_url: Discourse.base_url,
          cdn_url: Discourse.asset_host,
          s3_base_url: SiteSetting.Upload.enable_s3_uploads ? SiteSetting.Upload.s3_base_url : nil,
          s3_cdn_url: SiteSetting.Upload.enable_s3_uploads ? SiteSetting.Upload.s3_cdn_url : nil,
          db_name: RailsMultisite::ConnectionManagement.current_db,
          multisite: Rails.configuration.multisite,
          plugins: plugin_list,
        }

        data =
          @cached_data.merge({ uploads: @upload_stats, optimized_images: @optimized_image_stats })

        JSON.pretty_generate(data)
      end

      def plugin_list
        plugins = []

        Discourse.visible_plugins.each do |plugin|
          plugins << {
            name: plugin.name,
            enabled: plugin.enabled?,
            db_version: Database.current_plugin_migration_version(plugin),
            git_version: plugin.git_version,
          }
        end

        plugins.sort_by { |p| p[:name] }
      end
    end
  end
end
