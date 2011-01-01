class StoreCredit < ActiveRecord::Base
  attr_accessible :amount, :user_id

  belongs_to :user

  validates :user_id, :presence => true
  validates :amount , :presence => true

end
