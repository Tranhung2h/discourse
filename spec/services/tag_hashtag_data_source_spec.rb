# frozen_string_literal: true

RSpec.describe TagHashtagDataSource do
  fab!(:tag1) { Fabricate(:tag, name: "fact", topic_count: 0) }
  fab!(:tag2) { Fabricate(:tag, name: "factor", topic_count: 5) }
  fab!(:tag3) { Fabricate(:tag, name: "factory", topic_count: 4) }
  fab!(:tag4) { Fabricate(:tag, name: "factorio", topic_count: 3) }
  fab!(:tag5) { Fabricate(:tag, name: "factz", topic_count: 1) }
  fab!(:user) { Fabricate(:user) }
  let(:guardian) { Guardian.new(user) }

  describe "#search" do
    it "orders tag results by exact search match, then topic count, then name" do
      expect(described_class.search(guardian, "fact", 5).map(&:slug)).to eq(
        %w[fact factor factory factorio factz],
      )
    end

    it "does not get more than the limit" do
      expect(described_class.search(guardian, "fact", 1).map(&:slug)).to eq(%w[fact])
    end

    it "does not get tags that the user does not have permission to see" do
      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: ["fact"])
      expect(described_class.search(guardian, "fact", 5).map(&:slug)).not_to include("fact")
    end

    it "returns an array of HashtagAutocompleteService::HashtagItem" do
      expect(described_class.search(guardian, "fact", 1).first).to be_a(
        HashtagAutocompleteService::HashtagItem,
      )
    end

    it "includes the topic count for the text of the tag" do
      expect(described_class.search(guardian, "fact", 5).map(&:text)).to eq(
        ["fact x 0", "factor x 5", "factory x 4", "factorio x 3", "factz x 1"],
      )
    end

    it "returns nothing if tagging is not enabled" do
      SiteSetting.tagging_enabled = false
      expect(described_class.search(guardian, "fact", 5)).to be_empty
    end
  end

  describe "#search_without_term" do
    it "returns distinct tags sorted by topic_count" do
      expect(described_class.search_without_term(guardian, 5).map(&:slug)).to eq(
        %w[factor factory factorio factz fact],
      )
    end

    it "does not return tags the user does not have permission to view" do
      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: ["factor"])
      expect(described_class.search_without_term(guardian, 5).map(&:slug)).not_to include("factor")
    end

    it "does not return tags the user has muted" do
      TagUser.create(user: user, tag: tag2, notification_level: TagUser.notification_levels[:muted])
      expect(described_class.search_without_term(guardian, 5).map(&:slug)).not_to include("factor")
    end
  end
end
