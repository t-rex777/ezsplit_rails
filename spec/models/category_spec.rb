require 'rails_helper'

RSpec.describe Category, type: :model do
  let!(:user) { create(:user) }
  describe "associations" do
    it { should belong_to(:created_by).class_name("User").with_foreign_key("created_by_id") }
  end

  describe "validations" do
    subject(:category) do
      build(:category,
      name: "shopping", created_by_id: 1)
    end

    it "is valid with valid attributes" do
      expect(category).to be_valid
    end

    it "is not valid without a name" do
      category.name = nil
      expect(category).to_not be_valid
    end

    it "is not valid without a created_by_id" do
      category.created_by_id = nil
      expect(category).to_not be_valid
    end
  end
end
