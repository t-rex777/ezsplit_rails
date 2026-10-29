require "rails_helper"

RSpec.describe User, type: :model do
  describe "default categories" do
    it "gives a new user exactly the five default categories" do
      user = create(:user)

      expect(user.categories.order(:id).pluck(:name, :icon, :color)).to eq([
        [ "Grocery", "shopping_cart", "#5DCAA5" ],
        [ "Travel", "flight", "#B5D4F4" ],
        [ "Entertainment", "movie", "#AFA9EC" ],
        [ "Dining", "restaurant", "#FAC775" ],
        [ "Personal Care", "favorite", "#F4C0D1" ]
      ])
    end

    it "does not add them again when the user is updated" do
      user = create(:user)

      expect { user.update!(first_name: "Changed") }.not_to change { user.categories.count }
    end
  end
end
