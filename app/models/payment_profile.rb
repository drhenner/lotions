##  NOTE  Payment profile methods have been created however these methods have not been tested in any fashion
#   These method are here to give you a heads start.  Once CIM is created these methods will be ready for use.
#
# => Please refer to the following web page about seting up CIM.  This code has not been fully tested but
#     should serve you very well.
# http://cookingandcoding.com/2010/01/14/using-activemerchant-with-authorize-net-and-authorize-cim/
#
class PaymentProfile < ActiveRecord::Base
  include PaymentProfileCim
  belongs_to :user
  belongs_to :address

  attr_accessor       :request_ip, :credit_card

  validates :user_id,         :presence => true
  validates :payment_cim_id,  :presence => true
  validate            :validate_card
  #validates :address_id,      :presence => true

  #attr_accessible # none

  # method used by forms to credit a temp credit card
  #
  # ------------
  # behave like it's
  #   has_one :credit_card
  #   accepts_nested_attributes_for :credit_card_info
  #
  # @param [none]
  # @return [CreditCard]
  def credit_card_info=( card_or_params )
    credit_card = case card_or_params
      when ActiveMerchant::Billing::CreditCard, nil
        card_or_params
      else
        ActiveMerchant::Billing::CreditCard.new(card_or_params)
      end
    set_minimal_cc_data(credit_card)
  end

  # credit card object with known values
  #
  # @param [none]
  # @return [CreditCard]
  def new_credit_card
    # populate new card with some saved values
    ActiveMerchant::Billing::CreditCard.new(
      :first_name  => user.first_name,
      :last_name   => user.last_name,
      # :address etc too if we have it
      :type        => cc_type
    )
  end

  # -------------
  private

  def set_minimal_cc_data(card)
    self.last_digits  = card.last_digits
    self.month        = card.month
    self.year         = card.year
    self.first_name   = card.first_name.strip   if card.first_name?
    self.last_name    = card.last_name.strip    if card.last_name?
    self.cc_type      = card.type
  end

  def validate_card
    if credit_card.nil?
      errors.add_to_base 'Credit Card is not present'
      return false
    end
    # first validate via ActiveMerchant local code
    unless credit_card.valid?
      # collect credit card error messages into the profile object
      #errors.add(:credit_card, "must be valid")
      credit_card.errors.full_messages.each do |message|
        errors.add_to_base message
      end
      return
    end

    true
  end

end
