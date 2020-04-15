# frozen_string_literal: true

require_relative '../../../lib/logger/json_formatter'
RSpec.describe DT1::Logger::JsonFormatter do
  subject(:formatter) { described_class.new }

  describe '#format_exception!' do
    let(:bubling_exception) do
      begin
        begin
          raise FloatDomainError, 'root_cause'
        rescue FloatDomainError
          raise RangeError
        end
      rescue RangeError
        raise StandardError, 'wrapper of wrapper'
      end
    rescue StandardError => e
      e
    end

    context ''

    it 'contents message' do
      log_message = { message: 'Test', exception: bubling_exception }
      formatter.format_exception!(log_message)
      expect(log_message[:exception][:message]).to eq 'wrapper of wrapper'
    end

    it 'contents class' do
      log_message = { message: 'Test', exception: bubling_exception }
      formatter.format_exception!(log_message)
      expect(log_message[:exception][:class]).to eq 'StandardError'
    end

    it 'contents second cause message' do
      log_message = { message: 'Test', exception: bubling_exception }
      formatter.format_exception!(log_message)

      expect(log_message[:exception][:cause][:message]).to eq 'RangeError'
    end

    it 'contents cause class' do
      log_message = { message: 'Test', exception: bubling_exception }
      formatter.format_exception!(log_message)
      expect(log_message[:exception][:cause][:class]).to eq 'RangeError'
    end

    it 'contents root cause message' do
      log_message = { message: 'Test', exception: bubling_exception }
      formatter.format_exception!(log_message)
      expect(log_message[:exception][:cause][:cause][:message])
        .to eq 'root_cause'
    end

    it 'contents root cause class' do
      log_message = { message: 'Test', exception: bubling_exception }
      formatter.format_exception!(log_message)
      expect(log_message[:exception][:cause][:cause][:class])
        .to eq 'FloatDomainError'
    end
  end
end
