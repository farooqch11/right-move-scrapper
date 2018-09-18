class AddNewFieldEquity < ActiveRecord::Migration[5.2]
  def change
    add_column :properties, :equity_percentage, :integer
  end
end
