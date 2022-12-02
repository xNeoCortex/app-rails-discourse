# frozen_string_literal: true

require "rails_helper"

describe BackupRestoreV2::LoggerV2::FileLogChannel do
  let(:logfile) { StringIO.new }
  subject { described_class.new(logfile) }

  describe "#log" do
    it "logs all log levels" do
      freeze_time("2022-10-13T21:20:17Z")

      subject.log(::Logger::Severity::DEBUG, "debug message")
      subject.log(::Logger::Severity::INFO, "info message")
      subject.log(::Logger::Severity::WARN, "warn message")
      subject.log(::Logger::Severity::ERROR, "error message")
      subject.log(::Logger::Severity::FATAL, "fatal message")
      subject.log(::Logger::Severity::UNKNOWN, "unknown message")

      expect(logfile.string).to eq <<~TEXT
        [2022-10-13T21:20:17.0000Z] DEBUG -- debug message
        [2022-10-13T21:20:17.0000Z]  INFO -- info message
        [2022-10-13T21:20:17.0000Z]  WARN -- warn message
        [2022-10-13T21:20:17.0000Z] ERROR -- error message
        [2022-10-13T21:20:17.0000Z] FATAL -- fatal message
        [2022-10-13T21:20:17.0000Z]   ANY -- unknown message
      TEXT
    end

    it "logs the correct timestamp" do
      freeze_time("2022-10-13T21:20:17.0000Z")
      subject.log(::Logger::Severity::INFO, "info message")

      freeze_time("2022-10-13T21:20:17.0028Z")
      subject.log(::Logger::Severity::INFO, "info message")

      expect(logfile.string).to eq <<~TEXT
        [2022-10-13T21:20:17.0000Z]  INFO -- info message
        [2022-10-13T21:20:17.0028Z]  INFO -- info message
      TEXT
    end

    context "with exception" do
      let(:ex) do
        raise "Foo"
      rescue => e
        e
      end
      let(:backtrace) { ex.backtrace.join("\n") }

      it "logs exceptions" do
        freeze_time("2022-10-13T21:20:17Z")

        subject.log(::Logger::Severity::INFO, "info message", ex)
        subject.log(::Logger::Severity::ERROR, "error message", ex)

        expect(logfile.string).to eq <<~TEXT
          [2022-10-13T21:20:17.0000Z]  INFO -- info message
          [2022-10-13T21:20:17.0000Z]  INFO -- Foo (RuntimeError)
          #{backtrace}
          [2022-10-13T21:20:17.0000Z] ERROR -- error message
          [2022-10-13T21:20:17.0000Z] ERROR -- Foo (RuntimeError)
          #{backtrace}
        TEXT
      end
    end
  end

  describe "#close" do
    it "closes the file" do
      expect(logfile.closed?).to eq(false)
      subject.close
      expect(logfile.closed?).to eq(true)
    end
  end
end
