# Groups spending by category name, ignoring case.
#
# Categories belong to one user, so the same "Food" can exist once per person. Rows use the
# viewer's own category (name, icon, color) when they have one with that name.
class SpendingByCategory
  # pairs: [[category_id, amount], ...]. Returns rows sorted by amount, largest first.
  def self.rows(pairs, viewer)
    categories = Category.where(id: pairs.map(&:first).uniq).index_by(&:id)
    own = viewer.categories.index_by { |category| category.name.to_s.downcase }

    totals = Hash.new { |hash, key| hash[key] = { category: nil, amount: BigDecimal("0") } }
    pairs.each do |category_id, amount|
      category = categories[category_id]
      key = category.name.to_s.downcase
      totals[key][:category] ||= own[key] || category
      totals[key][:amount] += BigDecimal(amount.to_s)
    end

    totals.values
      .sort_by { |row| [ -row[:amount], row[:category].name.to_s.downcase ] }
      .map do |row|
        { name: row[:category].name, icon: row[:category].icon, color: row[:category].color, amount: row[:amount].to_s("F") }
      end
  end
end
