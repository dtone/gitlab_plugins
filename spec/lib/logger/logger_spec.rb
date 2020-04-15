# frozen_string_literal: true

require 'rspec/wait'

require_relative '../../../lib/logger/logger'
RSpec.describe DT1::Logger do
  let(:stdout) { StringIO.new }

  before do
    described_class.setup(outputter: stdout,
                          progname: 'test_logger',
                          log_level: ::Logger::DEBUG)
  end

  describe '#log' do
    %i[debug info warn error fatal].each do |severity|
      it "logs in severity #{severity}" do
        described_class.log(severity, message: 'Error message')
        wait_for { stdout.string }.to match(/Error message/)
      end
    end
  end
end
