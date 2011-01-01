require 'spec_helper'

describe StoreCredit do
  it "should be valid" do
    Factory.build(:store_credit).should be_valid
  end
end
