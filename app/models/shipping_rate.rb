class ShippingRate < ActiveRecord::Base
  include ActionView::Helpers::NumberHelper

  belongs_to :shipping_method
  belongs_to :shipping_rate_type

  belongs_to  :shipping_category
  has_many    :products

  validates  :rate,                   :presence => true, :numericality => true

  validates  :shipping_method_id,     :presence => true
  validates  :shipping_rate_type_id,  :presence => true
  validates  :shipping_category_id,   :presence => true

  scope :with_these_shipping_methods, lambda { |shipping_rate_ids, shipping_method_ids|
          {:conditions => ['shipping_rates.id IN (?) AND
                            shipping_rates.shipping_method_id IN (?)',shipping_rate_ids, shipping_method_ids]}
        }

  MONTHLY_BILLING_RATE_ID = 1

  # determines if the shippng rate should be calculated individually
  #
  # @param [none]
  # @return [ Boolean ]
  def individual?
    shipping_rate_type_id == ShippingRateType::INDIVIDUAL_ID
  end

  # the shipping method name, shipping zone and sub_name
  # ex. '3 to 5 day UPS, International, Individual - 5.50'
  #
  # @param [none]
  # @return [ String ]
  def name
    [shipping_method.name, shipping_method.shipping_zone.name, sub_name].join(', ')
  end

  # the shipping rate type and $$$ rate  separated by ' - '
  # ex. 'Individual - 5.50'
  #
  # @param [none]
  # @return [ String ]
  def sub_name
    '(' + [shipping_rate_type.name, rate ].join(' - ') + ')'
  end

  # the shipping method name, and $$$ rate
  # ex. '3 to 5 day UPS - $5.50'
  #
  # @param [none]
  # @return [ String ]
  def name_with_rate
    [shipping_method.name, number_to_currency(rate)].join(' - ')
  end

end
