# frozen_string_literal: true

module BackupRestoreV2
  module Backup
    class UploadStats
      attr_accessor :total_count, :included_count, :missing_count

      def initialize(total_count: 0, included_count: 0, missing_count: 0)
        @total_count = total_count
        @included_count = included_count
        @missing_count = missing_count
      end

      def as_json(options = {})
        {
          total_count: @total_count,
          included_count: @included_count,
          missing_count: @missing_count,
        }
      end

      def to_json(*options)
        as_json(*options).to_json(*options)
      end
    end
  end
end
