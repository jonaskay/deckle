require "rails_helper"
require "support/examples/pubsub_request_examples"

RSpec.describe "Pubsub::Deploy::Messages", type: :request do
  describe "POST /pubsub/deploy" do
    before { create(:deployment, project: project) }

    include_examples "pubsub message requests", :post, "/pubsub/deploy"
  end
end
