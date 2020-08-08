require "rails_helper"

RSpec.shared_examples "failed publish" do
  it { is_expected.to be false }

  it "doesn't update published_at" do
    expect { subject }.not_to change { project.reload.published_at }
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

  it "updates project to unpublished" do
    expect { subject }.to change { project.reload.unpublished? }
  end
end

RSpec.shared_examples "failed unpublish" do
  let(:cleaner) { class_double(Cleaner).as_stubbed_const }

  before { allow(cleaner).to receive(:clean).with(project) }

  it "doesn't call cleaner" do
    expect(cleaner).not_to receive(:clean)

    subject
  end

  it "doesn't update project to unpublished" do
    expect { subject }.not_to change { project.reload.unpublished? }
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

    it { is_expected.to eq("http://www.example.com/foo/index.html") }
  end

  describe "#published?" do
    subject { project.published? }

    context "when discarded is false and published_at is not nil" do
      let(:project) { create(:project, published_at: Time.current) }

      it { is_expected.to be true }
    end

    context "when discarded is true" do
      let(:project) { create(:project, :discarded, published_at: Time.current) }
    end

    context "when published_at is nil" do
      let(:project) { create(:project, published_at: nil) }

      it { is_expected.to be false }
    end
  end

  describe "#unpublished?" do
    subject { project.unpublished? }

    context "when published is true" do
      let(:project) { create(:project, :published) }

      it { is_expected.to be false }
    end

    context "when published is false" do
      let(:project) { create(:project, :published) }

      it { is_expected.to be false }
    end
  end

  describe "#deployed?" do
    subject { project.deployed? }

    context "when published is true and deployed_at is not nil" do
      let(:project) { create(:project, :published, deployed_at: Time.current) }

      it { is_expected.to be true }
    end

    context "when published is false" do
      let(:project) { create(:project, deployed_at: Time.current) }

      it { is_expected.to be false }
    end

    context "when deployed_at is nil" do
      let(:project) { create(:project, :published, deployed_at: nil) }

      it { is_expected.to be false }
    end
  end

  describe "#publish" do
    let(:publisher) { class_double("Publisher").as_stubbed_const }

    before { allow(publisher).to receive(:publish).and_return("foo") }

    subject { project.publish }

    context "when published_at is nil and discarded is false" do
      let(:project) { create(:project) }

      it { is_expected.to be true }

      it "updates published_at" do
        expect { subject }.to change { project.reload.published_at }
      end

      it "calls publisher" do
        expect(publisher).to receive(:publish)

        subject
      end
    end

    context "when discarded is true" do
      let(:project) { create(:project, :discarded) }

      include_examples "failed publish"
    end

    context "when published_at is not nil" do
      let(:project) { create(:project, :published) }

      include_examples "failed publish"
    end
  end

  describe "#unpublish" do
    let(:project) { create(:project, :published) }

    subject { project.unpublish }

    include_examples "successful unpublish"
  end

  describe "#confirm_deployment" do
    let(:project) { create(:project) }

    subject { project.confirm_deployment(DateTime.parse("1970-01-01T00:00:00.000Z")) }

    it "updateds project to deployed" do
      expect { subject }.to change { project.reload.deployed_at.to_s }.to("1970-01-01 00:00:00 UTC")
    end
  end

  describe "#confirm_cleanup" do
    subject { project.confirm_cleanup }

    context "when discarded is true" do
      let!(:project) { create(:project, :discarded) }

      it { is_expected.to be_a(Project) }

      it "deletes project" do
        expect { subject }.to change { Project.count }.by(-1)
      end
    end

    context "when discarded is false" do
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

    context "when project is published" do
      let(:project) { create(:project, :published) }

      include_examples "successful unpublish"
    end

    context "when project is not published" do
      let(:project) { create(:project) }

      include_examples "failed unpublish"
    end
  end
end