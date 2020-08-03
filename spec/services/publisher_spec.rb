require 'rails_helper'
require 'support/googleapis'

RSpec.describe Publisher, type: :model do
  include Googleapis

  describe ".publish" do
    before do
      handle_oauth_request

      stub(:compute, :insert_instance, params: {
        "project" => "my-project",
        "zone" => "my-zone",
        "template" => "my-publish-template"
      }).with_json('{ "id": "42" }')
    end

    let(:publication) { create(:publication, id: 1337) }

    subject { described_class.publish(publication) }

    it { is_expected.to be_a(Google::Apis::ComputeV1::Operation) }
  end

  describe ".unpublish" do
    before do
      handle_oauth_request

      stub(:compute, :insert_instance, params: {
        "project" => "my-project",
        "zone" => "my-zone",
        "template" => "my-unpublish-template"
      }).with_json('{ "id": "42" }')
    end

    let(:publication) { create(:publication, id: 1337, name: "foo") }

    subject { described_class.unpublish(publication) }

    it { is_expected.to be_a(Google::Apis::ComputeV1::Operation) }
  end
end
