# frozen_string_literal: true

module BackupRestoreV2
  module Logger
    class BaseProgressLogger
      def start(max_progress)
      end
      def increment
      end
      def log(message, ex = nil)
      end
    end
  end
end
