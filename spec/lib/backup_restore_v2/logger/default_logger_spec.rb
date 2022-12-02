# frozen_string_literal: true

require "rails_helper"

describe BackupRestoreV2::Logger::DefaultLogger do
  fab!(:admin) { Fabricate(:admin) }
  let(:operation) { "backup" }
  let(:client_id) { 42 }
  subject { described_class.new(admin.id, client_id, operation) }

  def expect_publish_on_message_bus(*messages)
    published_messages = freeze_time("2022-10-13T21:20:17Z") { MessageBus.track_publish { yield } }
    expect(published_messages.size).to eq(messages.size)

    messages.each_with_index do |message, index|
      published_message = published_messages[index]

      expected_attributes = {
        channel: BackupRestoreV2::LOGS_CHANNEL,
        user_ids: [admin.id],
        client_ids: [client_id],
      }
      expect(published_message).to have_attributes(expected_attributes)

      expected_data = { operation: "backup", message: message, timestamp: "2022-10-13 21:20:17" }
      expect(published_message.data).to include(expected_data)
    end
  end

  describe "#log_event" do
    it "publishes a message" do
      expect_publish_on_message_bus("Foo") { subject.log_event("Foo") }
    end

    it "doesn't output the event as log entry" do
      subject.log_event("Foo")
      expect(subject.logs).to be_empty
    end
  end

  describe "#log_step" do
    context "without progress" do
      it "logs the step name" do
        freeze_time("2022-10-13T21:20:17Z")
        subject.log_step("Step 1: Launch") {}
        expect(subject.logs).to eq(["[2022-10-13 21:20:17] Step 1: Launch"])
      end

      it "publishes a message" do
        expect_publish_on_message_bus("Step 2: Main Engine Cut Off") do
          subject.log_step("Step 2: Main Engine Cut Off") {}
        end
      end

      it "yields control" do
        expect { |block|
          subject.log_step("Step 3: Payload Separation", &block)
        }.to yield_with_no_args
      end
    end

    context "with progress" do
      it "logs the step name" do
        freeze_time("2022-10-13T21:20:17Z")
        subject.log_step("Step 4: Orbital Checkouts", with_progress: true) {}
        expect(subject.logs).to eq(["[2022-10-13 21:20:17] Step 4: Orbital Checkouts"])
      end

      it "publishes a message" do
        expect_publish_on_message_bus("Step 5: Fly-Under") do
          subject.log_step("Step 5: Fly-Under", with_progress: true) {}
        end
      end

      it "yields control" do
        expect { |block|
          subject.log_step("Step 6: Rendezvous", with_progress: true, &block)
        }.to yield_with_args(BackupRestoreV2::Logger::BaseProgressLogger)
      end
    end
  end

  describe "#log" do
    it "publishes a message" do
      expect_publish_on_message_bus("Foo bar") { subject.log("Foo bar") }
    end

    it "stores log entries" do
      freeze_time("2022-10-13T21:20:17Z") { subject.log("This is an info.") }

      freeze_time("2022-10-13T21:22:49Z") do
        subject.log("This is another info.", level: BackupRestoreV2::Logger::INFO)
        subject.log("This is a warning.", level: BackupRestoreV2::Logger::WARNING)
      end

      freeze_time("2022-10-13T21:23:38Z") do
        subject.log("This is an error.", level: BackupRestoreV2::Logger::ERROR)
      end

      expect(subject.logs).to eq(
        [
          "[2022-10-13 21:20:17] INFO This is an info.",
          "[2022-10-13 21:22:49] INFO This is another info.",
          "[2022-10-13 21:22:49] WARN This is a warning.",
          "[2022-10-13 21:23:38] ERROR This is an error.",
        ],
      )
    end
  end

  describe "#log_warning" do
    it "enables the warning? flag" do
      expect(subject.warnings?).to eq(false)

      subject.log_error("Error")
      expect(subject.warnings?).to eq(false)

      subject.log_warning("Warning")
      expect(subject.warnings?).to eq(true)
    end
  end

  describe "#log_error" do
    it "enables the errors? flag" do
      expect(subject.errors?).to eq(false)

      subject.log_warning("Warning")
      expect(subject.errors?).to eq(false)

      subject.log_error("Error")
      expect(subject.errors?).to eq(true)
    end
  end

  describe "#warnings?" do
    it "returns true when warnings have been logged with `#log_warning`" do
      expect(subject.warnings?).to eq(false)
      subject.log_warning("Foo")
      expect(subject.warnings?).to eq(true)
    end

    it "returns true when warnings have been logged with `#log`" do
      expect(subject.warnings?).to eq(false)

      subject.log("Foo")
      expect(subject.warnings?).to eq(false)

      subject.log("Error", level: BackupRestoreV2::Logger::ERROR)
      expect(subject.warnings?).to eq(false)

      subject.log("Warning", level: BackupRestoreV2::Logger::WARNING)
      expect(subject.warnings?).to eq(true)
    end
  end

  describe "#errors?" do
    it "returns true when errors have been logged with `#log_error`" do
      expect(subject.errors?).to eq(false)
      subject.log_error("Foo")
      expect(subject.errors?).to eq(true)
    end

    it "returns true when warnings have been logged with `#log`" do
      expect(subject.errors?).to eq(false)

      subject.log_warning("Warning")
      expect(subject.errors?).to eq(false)

      subject.log("Foo")
      expect(subject.errors?).to eq(false)

      subject.log("Warning", level: BackupRestoreV2::Logger::WARNING)
      expect(subject.errors?).to eq(false)

      subject.log("Error", level: BackupRestoreV2::Logger::ERROR)
      expect(subject.errors?).to eq(true)
    end
  end
end
