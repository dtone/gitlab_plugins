# frozen_string_literal: true

require 'json'

require_relative '../../../../lib/notifiers/slack/slack_notifier'

RSpec.describe SlackNotifier do
  let(:channel) { 'DN1GOIFFC' }
  let(:workspace) { 'dtone' }

  describe '#notify' do
    subject(:notifier) do
      described_class.new(allow_notify: true, channel: channel,
                          invite: false,
                          webhook: webhook,
                          workspace: workspace)
    end

    let(:reports) { [report] }
    let(:webhook) { 'https://dtone.slack.com/api/webhook' }

    let(:report) do
      {
        type: :info,
        title: 'Test title',
        pretext: 'Pretext from rspec',
        text: 'Long rspec test'
      }
    end
    let(:expected_body) do
      {
        as_user: false,
        link_names: true,
        parse: :full,
        text: nil,
        attachments: [
          { actions: [], color: :good,
            title: report[:title],
            pretext: report[:pretext],
            text: report[:text] }.merge(
              SlackNotifier::AttachmentFormatter.attachment_default_with_person
            )
        ]
      }
    end

    before do
      allow(SlackNotifier::AttachmentFormatter::INTERESTING_PERSONS)
        .to receive(:sample).and_return('Rumcajs')
    end

    it 'sends message to slack' do
      stub_request(:post, webhook)
        .with(body: expected_body.to_json)
      notifier.notify(reports)
    end
  end

  describe '#mention' do
    context 'with log level in report' do
      subject(:notifier) { described_class.new(mention: true) }

      it 'returns false not to mention people on debug' do
        expect(notifier.mention?(type: :debug)).to be false
      end

      it 'returns false not to mention people on info' do
        expect(notifier.mention?(type: :info)).to be false
      end

      it 'returns true not to mention people on warn' do
        expect(notifier.mention?(type: :warn)).to be true
      end

      it 'returns true not to mention people on error' do
        expect(notifier.mention?(type: :error)).to be true
      end
    end

    context 'when mention is disabled globaly' do
      subject(:notifier) { described_class.new(mention: false) }

      it 'returns false not to mention people on debug' do
        expect(notifier.mention?(type: :debug)).to be false
      end

      it 'returns false not to mention people on error' do
        expect(notifier.mention?(type: :error)).to be false
      end
    end
  end

  describe '#invite_url' do
    subject(:notifier) { described_class.new(workspace: workspace) }

    it 'returns invite url' do
      expect(notifier.invite_url)
        .to eq('https://dtone.slack.com/api/channels.invite')
    end
  end

  describe '#user_list_url' do
    subject(:notifier) { described_class.new(workspace: workspace) }

    it 'returns invite url' do
      expect(notifier.user_list_url)
        .to eq('https://dtone.slack.com/api/users.list')
    end
  end

  describe '#invite' do
    subject(:notifier) do
      described_class.new(allow_notify: true, channel: channel,
                          invite: true, workspace: workspace)
    end

    before do
      stub_request(:post, 'https://dtone.slack.com/api/users.list')
        .to_return(body:
          '{"members": [{"id":"99","profile":{"email":"john.snow@ox.ac.uk"}}]}')
    end

    it 'invites user' do
      stub_request(:post, 'https://dtone.slack.com/api/channels.invite')
        .with(body: '{"channel":"DN1GOIFFC","user":"99"}')
      notifier.invite(user: { email: 'john.snow@ox.ac.uk' })
    end

    it 'does not invite user' do
      # this expects does not call channel.invite when it calls
      # webmock throws an erropr
      notifier.invite(user: { email: 'jon.snow@targaryen.fantasy' })
    end
  end
end
