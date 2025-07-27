require 'rails_helper'

RSpec.describe ExpensesUser, type: :model do
  let!(:user) { create(:user) }
  let!(:group) { create(:group, created_by: user) }
  let!(:category) { create(:category, created_by: user) }
  let!(:expense) { create(:expense, payer: user, group: group, category: category) }

  describe 'associations' do
    it { should belong_to(:expense) }
    it { should belong_to(:user) }
  end

  describe 'validations' do
    let!(:expenses_user) { build(:expenses_user, expense: expense, user: user) }
    subject { expenses_user }

    it { should validate_presence_of(:user_id) }
    it { should validate_presence_of(:expense_id) }
    it { should validate_presence_of(:amount) }

    context 'paid attribute' do
      it 'sets paid to true when user is the payer' do
        expenses_user.valid?
        expect(expenses_user.paid).to be true
      end

      it 'sets paid to false when user is not the payer' do
        other_user = create(:user)
        expenses_user.user = other_user
        expenses_user.valid?
        expect(expenses_user.paid).to be false
      end

      it 'requires paid to be set' do
        expenses_user.paid = nil
        expenses_user.valid?
        expect(expenses_user.paid).to be true
      end
    end
  end
end
