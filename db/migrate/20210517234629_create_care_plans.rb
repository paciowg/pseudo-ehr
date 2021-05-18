class CreateCarePlans < ActiveRecord::Migration[5.2]
  def change
    create_table :care_plans do |t|

      t.timestamps
    end
  end
end
