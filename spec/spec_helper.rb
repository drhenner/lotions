# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'shoulda/integrations/rspec2' # Add this line
require "authlogic/test_case"
require 'shoulda'
require 'mocha'
require "email_spec"

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}
# Requires supporting files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
#Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

include Hadean::TruncateHelper
include Hadean::TestHelpers
include Authlogic::TestCase
include ActiveMerchant::Billing

RSpec.configure do |config|
  # == Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr
  # config.mock_with :rspec
  config.include(EmailSpec::Helpers)
  config.include(EmailSpec::Matchers)


  config.before(:suite) { trunctate_unseeded }

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  # config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true
  #config.logger = :stdout
  #Product.configuration[:if] = false
  config.before(:each) do

    User.any_instance.stubs(:create_cim_profile).returns(true)
    User.any_instance.stubs(:update_cim_profile).returns(true)
    User.any_instance.stubs(:delete_cim_profile).returns(true)

    ::Sunspot.session = ::Sunspot::Rails::StubSessionProxy.new(::Sunspot.session)
  end

  config.after(:each) do
    ::Sunspot.session = ::Sunspot.session.original_session
  end
end

class ActionController::TestCase
  include Authlogic::TestCase
  #setup :activate_authlogic
end

def with_solr
  Product.configuration[:if] = 'true'
  yield
  Product.configuration[:if] = false
end

  def credit_card_hash(options = {})
    { :number     => '1',
      :first_name => 'Johnny',
      :last_name  => 'Dee',
      :month      => '8',
      :year       => "#{ Time.now.year + 1 }",
      :verification_value => '323',
      :type       => 'visa'
    }.update(options)
  end

  def credit_card(options = {})
    ActiveMerchant::Billing::CreditCard.new( credit_card_hash(options) )
  end

  # -------------Payment profile and payment could use this
  def example_credit_card_params( params = {})
    default = {
      :first_name         => 'First Name',
      :last_name          => 'Last Name',
      :type               => 'visa',
      :number             => '4111111111111111',
      :month              => '10',
      :year               => '2012',
      :verification_value => '999'
    }.merge( params )

    specific = case gateway_name #SubscriptionConfig.gateway_name
      when 'authorize_net_cim'
        {
          :type               => 'visa',
          :number             => '4007000000027',
        }
        # 370000000000002 American Express Test Card
        # 6011000000000012 Discover Test Card
        # 4007000000027 Visa Test Card
        # 4012888818888 second Visa Test Card
        # 3088000000000017 JCB
        # 38000000000006 Diners Club/ Carte Blanche

      when 'bogus'
        {
          :type               => 'bogus',
          :number             => '1',
        }

      else
        {}
      end

    default.merge(specific).merge(params)
  end

  def successful_unstore_response
    'transaction_id=d79410c91b4b31ba99f5a90558565df9&error_code=000&auth_response_text=Stored Card Data Deleted'
  end
