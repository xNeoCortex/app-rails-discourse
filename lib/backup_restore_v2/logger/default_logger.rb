# frozen_string_literal: true

module BackupRestoreV2
  module Logger
    class DefaultLogger < BaseLogger
      # @param operation "backup" or "restore"
      def initialize(user_id, client_id, operation)
        super()
        @user_id = user_id
        @client_id = client_id
        @operation = operation
        @logs = []
      end

      # Events are used by the UI, so we need to publish it via MessageBus.
      def log_event(event)
        publish_log(event, create_timestamp)
      end

      def log(message, level: Logger::INFO)
        timestamp = create_timestamp
        publish_log(message, timestamp)
        save_log(message, timestamp)

        case level
        when Logger::WARNING
          @warning_count += 1
        when Logger::ERROR
          @error_count += 1
        end
      end

      private

      def publish_log(message, timestamp)
        data = { timestamp: timestamp, operation: @operation, message: message }
        MessageBus.publish(
          BackupRestoreV2::LOGS_CHANNEL,
          data,
          user_ids: [@user_id],
          client_ids: [@client_id],
        )
      end

      def save_log(message, timestamp)
        @logs << "[#{timestamp}] #{message}"
      end
    end
  end
end
