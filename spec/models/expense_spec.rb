require 'rails_helper'

RSpec.describe Expense, type: :model do
  let!(:user) { create(:user) }
  let!(:group) { create(:group, created_by: user) }
  let!(:category) { create(:category, created_by: user) }

  describe "associations" do
    it { is_expected.to belong_to(:payer).class_name("User").with_foreign_key(:payer_id) }
    it { is_expected.to belong_to(:group).class_name("Group").with_foreign_key(:group_id) }
    it { is_expected.to belong_to(:category).class_name("Category").with_foreign_key(:category_id) }
  end

  describe "validations" do
    context "with valid parameters" do
      let(:expense) { create(:expense, payer: user, group: group, category: category) }

      it "is valid" do
        expect(expense).to be_valid
      end
    end

    context "with invalid parameters" do
      let(:expense) { build(:expense, payer: user, group: group, category: category) }

      it "is invalid when name is not present" do
        expense.name = nil
        expect(expense).to be_invalid
      end

      it "is invalid when amount is not present" do
        expense.amount = nil
        expect(expense).to be_invalid
      end

      it "is invalid when payer is not present" do
        expense.payer = nil
        expect(expense).to be_invalid
      end

      it "is invalid when group is not present" do
        expense.group = nil
        expect(expense).to be_invalid
      end

      it "is invalid when category is not present" do
        expense.category = nil
        expect(expense).to be_invalid
      end

      it "is invalid when split_type is not present" do
        expense.split_type = nil
        expect(expense).to be_invalid
      end

      it "is invalid when currency is not present" do
        expense.currency = nil
        expect(expense).to be_invalid
      end

      it "is invalid when expense_date is not present" do
        expense.expense_date = nil
        expect(expense).to be_invalid
      end

      it "is invalid when split_type is not in the list of allowed split types" do
        expense.split_type = "invalid"
        expect(expense).to be_invalid
      end

      it "is invalid when currency is not in the list of allowed currencies" do
        expense.currency = "invalid"
        expect(expense).to be_invalid
      end
    end
  end
end
