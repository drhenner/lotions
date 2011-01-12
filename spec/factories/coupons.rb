# Read about factories at http://github.com/thoughtbot/factory_girl

Factory.define :coupon do |f|
  f.type "MyString"
  f.code "MyString"
  f.amount "9.99"
  f.minimum_value "9.99"
  f.percent 1
  f.description "MyText"
  f.combine false
  f.starts_at "2011-01-10 17:14:44"
  f.expires_at "2011-01-10 17:14:44"
end
