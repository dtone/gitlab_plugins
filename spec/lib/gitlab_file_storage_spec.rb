# frozen_string_literal: true

require 'json'

require_relative '../../lib/gitlab_file_storage'

class Test
  include DT1::GitLabFileStorage

  def initialize(project_id)
    @project_id = project_id
  end

  def read
    @data = gitlab_plugins_attrs(@project_id)
  end

  def modify
    @data[:new_key] = :new_value
    @update_file = true
  end

  def update
    store_to_remote_file(@project_id, @data)
  end
end

RSpec.describe DT1::GitLabFileStorage do
  subject(:tested_instance) { Test.new(project_id) }

  let(:attrs) { { 'key' => 'original_value' } }

  let(:content) { attrs.to_json }

  let(:base64_content) do
    Base64.encode64(content)
  end

  let(:gitlab_file) do
    Gitlab::ObjectifiedHash.new(
      content: base64_content
    )
  end

  let(:gitlab_mr) do
    Gitlab::ObjectifiedHash.new(
      id: rand(1000),
      iid: rand(1000)
    )
  end

  let(:project_id) { 42 }

  before do
    allow(Gitlab)
      .to receive(:get_file).with(project_id, '.gitlab_plugins', :master)
                            .and_return(gitlab_file)
    allow(Gitlab).to receive(:create_file)
    allow(Gitlab).to receive(:create_branch)
    allow(Gitlab).to receive(:create_merge_request).and_return(gitlab_mr)
    allow(Gitlab).to receive(:accept_merge_request)
  end

  it 'reads file' do
    expect(tested_instance.read).to eq(attrs)
  end

  it 'does not store file' do
    expect(Gitlab).not_to receive(:create_file)
    tested_instance.read
    tested_instance.update
  end

  it 'creates file' do
    expect(Gitlab).to receive(:create_file)
    tested_instance.read
    tested_instance.modify
    tested_instance.update
  end

  it 'creates branch' do
    expect(Gitlab).to receive(:create_branch)
      .with(project_id, :update_gitlab_plugins_file, :master)
    tested_instance.read
    tested_instance.modify
    tested_instance.update
  end

  it 'creates MR' do
    expect(Gitlab).to receive(:create_merge_request)
      .with(project_id, 'Update gitlab_plugins file',
            source_branch: :update_gitlab_plugins_file,
            target_branch: :master).and_return(gitlab_mr)
    tested_instance.read
    tested_instance.modify
    tested_instance.update
  end

  it 'accepts MR' do
    expect(Gitlab).to receive(:accept_merge_request)
      .with(project_id, gitlab_mr.iid,
            merge_commit_message: 'auto accept',
            should_remove_source_branch: true)
    tested_instance.read
    tested_instance.modify
    tested_instance.update
  end
end
