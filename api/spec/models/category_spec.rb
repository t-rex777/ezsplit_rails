require 'rails_helper'

RSpec.describe Category, type: :model do
  let!(:user) { create(:user) }
  describe "associations" do
    it { should belong_to(:user) }
  end

  describe "validations" do
    subject(:category) do
      build(:category,
      name: "shopping", user: user)
    end

    it "is valid with valid attributes" do
      expect(category).to be_valid
    end

    it "is not valid without a name" do
      category.name = nil
      expect(category).to_not be_valid
    end

    it "is not valid without a user" do
      category.user = nil
      expect(category).to_not be_valid
    end
  end
end
