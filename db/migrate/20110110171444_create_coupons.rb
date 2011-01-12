class CreateCoupons < ActiveRecord::Migration
  def self.up
    create_table :coupons do |t|
      t.string :type
      t.string :code
      t.decimal :amount
      t.decimal :minimum_value
      t.integer :percent
      t.text :description
      t.boolean :combine
      t.datetime :starts_at
      t.datetime :expires_at

      t.timestamps
    end
  end

  def self.down
    drop_table :coupons
  end
end
