namespace :dazzle do
  namespace :billing do
    #
    desc "Setup subscription fee"
    task :setup_subscription_fee => :environment do
      users_to_charge = User.find_subscription_users.include_default_addresses
      users_to_charge.each do |user|
        Order.create_subscription_order(user)
      end
    end
  end
end