require "rails_helper"

RSpec.shared_context "with finished deployment" do
  before { create(:deployment, :finished, project: project) }
end

RSpec.shared_examples "with failed deployment" do
  before { create(:deployment, :failed, project: project) }
end

RSpec.shared_examples "successful publish" do
  it { is_expected.to be true }

  it "updates released_at" do
    expect { subject }.to change { project.reload.released_at }
  end

  it "calls publisher" do
    expect(publisher).to receive(:publish)

    subject
  end
end

RSpec.shared_examples "skipped publish" do
  it { is_expected.to be false }

  it "doesn't update released_at" do
    expect { subject }.not_to change { project.reload.released_at }
  end

  it "doesn't call publisher" do
    expect(publisher).not_to receive(:publish)

    subject
  end
end

RSpec.shared_examples "successful unpublish" do
  let(:cleaner) { class_double(Cleaner).as_stubbed_const }

  before { allow(cleaner).to receive(:clean).with(project) }

  it "calls cleaner" do
    expect(cleaner).to receive(:clean).with(project)

    subject
  end

  it "updates project to hidden" do
    expect { subject }.to change { project.reload.hidden? }
  end
end

RSpec.shared_examples "skipped unpublish" do
  let(:cleaner) { class_double(Cleaner).as_stubbed_const }

  before { allow(cleaner).to receive(:clean).with(project) }

  it "doesn't call cleaner" do
    expect(cleaner).not_to receive(:clean)

    subject
  end

  it "doesn't update project to hidden" do
    expect { subject }.not_to change { project.reload.hidden? }
  end
end

RSpec.describe Project, type: :model do
  describe "#valid?" do
    let(:project) { build(:project) }

    subject { project.valid? }

    it { is_expected.to be true }

    context "when user is nil" do
      let(:project) { build(:project, user: nil) }

      it { is_expected.to be false }
    end

    context "when title is blank" do
      let(:project) { build(:project, title: "   ") }

      it { is_expected.to be false }
    end

    context "when name is blank" do
      let(:project) { build(:project, name: "   ") }

      it { is_expected.to be false }
    end

    context "when name is taken" do
      let(:project) { build(:project, name: "foo") }

      before { create(:project, name: "foo") }

      it { is_expected.to be false }
    end

    context "when name is 63 characters long" do
      let(:project) { build(:project, name: "a" * 63) }

      it { is_expected.to be true }
    end

    context "when name is longer than 63 characters" do
      let(:project) { build(:project, name: "a" * 64) }

      it { is_expected.to be false }
    end

    context "when name contains uppercase letters" do
      let(:project) { build(:project, name: "fooBarBaz") }

      it { is_expected.to be false }
    end

    context "when name contains digits" do
      let(:project) { build(:project, name: "f00b4rb4z") }

      it { is_expected.to be true }
    end

    context "when name contains dashes" do
      let(:project) { build(:project, name: "foo-bar-baz") }

      it { is_expected.to be true }
    end

    context "when name contains underscores" do
      let(:project) { build(:project, name: "foo_bar_baz") }

      it { is_expected.to be false }
    end

    context "when name contains whitespace characters" do
      let(:project) { build(:project, name: "foo bar baz") }

      it { is_expected.to be false }
    end

    context "when name starts with a letter" do
      let(:project) { build(:project, name: "foo") }

      it { is_expected.to be true }
    end

    context "when name starts with a number" do
      let(:project) { build(:project, name: "1337") }

      it { is_expected.to be true }
    end

    context "when name starts with a dash" do
      let(:project) { build(:project, name: "-foo") }

      it { is_expected.to be false }
    end

    context "when name ends with a dash" do
      let(:project) { build(:project, name: "foo-") }

      it { is_expected.to be false }
    end
  end

  describe "#url" do
    let(:project) { build(:project, name: "foo") }

    subject { project.url }

    it { is_expected.to eq "http://www.example.com/foo/index.html" }
  end

  describe "#hidden?" do
    subject { project.hidden? }

    context "when released? is true" do
      let(:project) { create(:project, :released) }

      it { is_expected.to be false }
    end

    context "when released? is false" do
      let(:project) { create(:project) }

      it { is_expected.to be true }
    end
  end

  describe "#released?" do
    subject { project.released? }

    context "when released_at is nil" do
      let(:project) { create(:project, released_at: nil) }

      it { is_expected.to be false }
    end

    context "when released_at is not nil" do
      let(:project) { create(:project, released_at: Time.current) }

      it { is_expected.to be true }
    end
  end

  describe "#deployed?" do
    let(:project) { create(:project) }

    subject { project.deployed? }

    context "when there are no deployments" do
      it { is_expected.to be false }
    end

    context "when there is one deployment" do
      context "when deployment has finished" do
        include_context "with finished deployment"

        it { is_expected.to be true }
      end

      context "when deployment has failed" do
        include_context "with failed deployment"

        it { is_expected.to be false }
      end
    end

    context "when there are two deployments" do
      context "when both deployments have finished" do
        include_context "with finished deployment"
        include_context "with finished deployment"

        it { is_expected.to be true }
      end

      context "when both deployments have failed" do
        include_context "with failed deployment"
        include_context "with failed deployment"

        it { is_expected.to be false }
      end

      context "when first deployment has finished and second deployment failed" do
        include_context "with finished deployment"
        include_context "with failed deployment"

        it { is_expected.to be true }
      end

      context "when first deployment has failed and second deployment finished" do
        include_context "with failed deployment"
        include_context "with finished deployment"

        it { is_expected.to be true }
      end
    end
  end

  describe "#published?" do
    subject { project.published? }

    context "when released? is true and deployed? is true" do
      let(:project) { create(:project, :released, :deployed) }

      it { is_expected.to be true }
    end

    context "when released? is true" do
      let(:project) { create(:project, :released) }

      it { is_expected.to be false }
    end

    context "when deployed? is true" do
      let(:project) { create(:project, :deployed) }

      it { is_expected.to be false }
    end
  end

  describe "#deployment_failed?" do
    let(:project) { create(:project) }

    subject { project.deployment_failed? }

    context "when there are no deployments" do
      it { is_expected.to be false }
    end

    context "when there is one deployment" do
      context "when deployment has finished" do
        include_context "with finished deployment"

        it { is_expected.to be false }
      end

      context "when deployment has failed" do
        include_context "with failed deployment"

        it { is_expected.to be true }
      end
    end

    context "when there are two deployments" do
      context "when both deployments have finished" do
        include_context "with finished deployment"
        include_context "with finished deployment"

        it { is_expected.to be false }
      end

      context "when both deployments have failed" do
        include_context "with failed deployment"
        include_context "with failed deployment"

        it { is_expected.to be true }
      end

      context "when first deployment has finished and second deployment failed" do
        include_context "with finished deployment"
        include_context "with failed deployment"

        it { is_expected.to be true }
      end

      context "when first deployment has failed and second deployment finished" do
        include_context "with failed deployment"
        include_context "with finished deployment"

        it { is_expected.to be false }
      end
    end
  end

  describe "#deployment_fail_message" do
    subject { project.deployment_fail_message }

    context "when deployment_failed? is true" do
      let(:project) { create(:project, :deployment_failed) }

      it { is_expected.to eq "fail" }
    end

    context "when deployment_failed? is false" do
      let(:project) { create(:project) }

      it { is_expected.to be_nil }
    end
  end

  describe "#current_deployment" do
    let(:project) { create(:project) }
    let!(:first_project) { create(:deployment, project: project, created_at: 2.hours.ago) }
    let!(:second_project) { create(:deployment, project: project, created_at: 1.hour.ago) }
    let!(:third_project) { create(:deployment, project: project, created_at: 3.hours.ago) }

    subject { project.current_deployment }

    it { is_expected.to eq second_project }
  end

  describe "#status" do
    subject { project.status }

    context "when released? is true" do
      context "when deployed? is true" do
        context "when discarded? is true" do
          let(:project) { create(:project, :released, :deployed, :discarded) }

          it { is_expected.to eq "Deleting" }
        end

        context "when discarded? is false" do
          let(:project) { create(:project, :released, :deployed) }

          it { is_expected.to eq "Published" }
        end
      end

      context "when deployed? is false" do
        context "when discarded? is true" do
          context "when deployment_failed? is true" do
            let(:project) { create(:project, :released, :discarded, :deployment_failed) }

            it { is_expected.to eq "Deleting" }
          end

          context "when deployment_failed? is false" do
            let(:project) { create(:project, :released, :discarded) }

            it { is_expected.to eq "Deleting" }
          end
        end

        context "when discarded? is false" do
          context "when deployment_failed? is true" do
            let(:project) { create(:project, :released, :deployment_failed) }

            it { is_expected.to eq "Error" }
          end

          context "when deployment_failed? is false" do
            let(:project) { create(:project, :released) }

            it { is_expected.to eq "Publishing" }
          end
        end
      end
    end

    context "when hidden? is true" do
      context "when discarded? is true" do
        let(:project) { create(:project, :discarded) }

        it { is_expected.to eq "Deleting" }
      end

      context "when discarded? is false" do
        let(:project) { create(:project) }

        it { is_expected.to eq "Unpublished" }
      end
    end
  end

  describe "#publish" do
    let(:publisher) { class_double("Publisher").as_stubbed_const }

    before { allow(publisher).to receive(:publish).and_return("foo") }

    subject { project.publish }

    context "when released_at? is false and discarded? is false" do
      let(:project) { create(:project) }

      include_examples "successful publish"
    end

    context "when discarded? is true" do
      let(:project) { create(:project, :discarded) }

      include_examples "skipped publish"
    end

    context "when released_at? is true" do
      context "when deployment_failed? is true" do
        let(:project) { create(:project, :released, :deployment_failed) }

        include_examples "successful publish"
      end

      context "when deployment_failed? is false" do
        let(:project) { create(:project, :released) }

        include_examples "skipped publish"
      end
    end
  end

  describe "#unpublish" do
    let(:project) { create(:project, :published) }

    subject { project.unpublish }

    include_examples "successful unpublish"
  end

  describe "#confirm_cleanup" do
    subject { project.confirm_cleanup }

    context "when discarded? is true" do
      let!(:project) { create(:project, :discarded) }

      it { is_expected.to be_a(Project) }

      it "deletes project" do
        expect { subject }.to change { Project.count }.by(-1)
      end
    end

    context "when discarded? is false" do
      let!(:project) { create(:project) }

      it { is_expected.to be false }

      it "doesn't delete project" do
        expect { subject }.not_to change { Project.count }
      end
    end
  end

  context "when project is updated" do
    let(:project) { create(:project, title: "foo", name: "foo") }

    subject { project.update(title: "bar", name: "bar") }

    it "prevents name updates" do
      expect { subject }.not_to change { project.reload.name }
    end
  end

  context "when project is discarded" do
    subject { project.discard }

    context "when published? is true" do
      let(:project) { create(:project, :published) }

      include_examples "successful unpublish"
    end

    context "when published? is false" do
      let(:project) { create(:project) }

      context "when released? is true" do
        skip "hides project"
      end

      context "when released? is false" do
        include_examples "skipped unpublish"

        context "when deployed? is true" do
          skip "removes deployment"
        end
      end
    end
  end

  context "when project is destroyed" do
    let(:project) { create(:project) }

    subject { project.destroy }

    it "destroys any deployments" do
      create(:deployment, project: project)

      expect { subject }.to change { Deployment.count }.by(-1)
    end
  end
end
