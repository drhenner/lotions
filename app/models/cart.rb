class Cart < ActiveRecord::Base
  belongs_to  :user
  has_many    :cart_items
  has_many    :shopping_cart_items,       :conditions => ['cart_items.active = ? AND
                                                          cart_items.item_type_id = ?', true, ItemType::SHOPPING_CART_ID],
                                          :class_name => 'CartItem'


  has_many    :saved_cart_items,          :conditions => ['cart_items.active = ? AND
                                                          cart_items.item_type_id = ?', true, ItemType::SAVE_FOR_LATER_ID],
                                          :class_name => 'CartItem'
  has_many    :wish_list_items,           :conditions => ['cart_items.active = ? AND
                                                          cart_items.item_type_id = ?', true, ItemType::WISH_LIST_ID],
                                          :class_name => 'CartItem'

  has_many    :purchased_items,           :conditions => ['cart_items.active = ? AND
                                                          cart_items.item_type_id = ?', true, ItemType::PURCHASED_ID],
                                          :class_name => 'CartItem'

  has_many    :deleted_cart_items,        :conditions => ['cart_items.active = ?', false], :class_name => 'CartItem'

  # Adds all the item prices (not including taxes) that are currently in the shopping cart
  #
  # @param [none]
  # @return [Float] This is a float in decimal form and represents the price of all the items in the cart
  def sub_total
    shopping_cart_items.inject(0) {|sum, item| item.total + sum} #.includes(:variant)
  end

  # Call this method when you are checking out with the current cart items
  # => these will now be order.order_items
  # => the order can only add items if it is 'in_progress'
  #
  # @param [Order] order to insert the shopping cart variants into
  # @return [none]
  def add_items_to_checkout(order)
    if order.in_progress?
      items = shopping_cart_items.inject({}) {|h, item| h[item.variant_id] = item.quantity; h}
      items_to_add_or_destroy(items, order)
    end
  end

  # Call this method when you want to add an item to the shopping cart
  #
  # @param [Integer, #read] variant id to add to the cart
  # @param [User, #read] user that is adding something to the cart
  # @param [Integer, #optional] ItemType id that is being added to the cart
  # @return [CartItem] return the cart item that is added to the cart
  def add_variant(variant_id, customer, qty = 1, cart_item_type_id = ItemType::SHOPPING_CART_ID)
    items = shopping_cart_items.find_all_by_variant_id(variant_id)
    variant = Variant.find(variant_id)
    unless variant.sold_out?
      if items.size < 1
        cart_item = shopping_cart_items.create(:variant_id   => variant_id,
                                      :user         => customer,
                                      :item_type_id => cart_item_type_id,
                                      :quantity     => qty#,#:price      => variant.price
                                      )
      else
        cart_item = items.first
        update_shopping_cart(cart_item,customer, qty)
      end
    else
      cart_item = saved_cart_items.create(:variant_id   => variant_id,
                                    :user         => customer,
                                    :item_type_id => ItemType::SAVE_FOR_LATER_ID,
                                    :quantity     => qty#,#:price      => variant.price
                                    ) if items.size < 1

    end
    cart_item
  end

  # Call this method when you want to remove an item from the shopping cart
  #   The CartItem will not delete.  Instead it is just inactivated
  #
  # @param [Integer, #read] variant id to add to the cart
  # @return [CartItem] return the cart item that is added to the cart
  def remove_variant(variant_id)
    citems = self.cart_items.each {|ci| ci.inactivate! if variant_id.to_i == ci.variant_id }
    return citems
  end

  # Call this method when you want to associate the cart with a user
  #
  # @param [User]
  def save_user(u)  # u is user object or nil
    if u && self.user_id != u.id
      self.user_id = u.id
      self.save
    end
  end

  # Call this method when you want to mark the items in the order as purchased
  #   The CartItem will not delete.  Instead the item_type changes to purchased
  #
  # @param [Order]
  def mark_items_purchased(order)
    CartItem.update_all("item_type_id = #{ItemType::PURCHASED_ID}",
                        "id IN (#{(self.cart_item_ids + self.shopping_cart_item_ids).uniq.join(',')}) AND variant_id IN (#{order.variant_ids.join(',')})") if !order.variant_ids.empty?
  end

  private
  def update_shopping_cart(cart_item,customer, qty = 1)
    if customer
      self.shopping_cart_items.find(cart_item.id).update_attributes(:quantity => (cart_item.quantity + qty), :user_id => customer.id)
    else
      self.shopping_cart_items.find(cart_item.id).update_attributes(:quantity => (cart_item.quantity + qty))
    end
  end

  def items_to_add_or_destroy(items_in_cart, order)
    #destroy_any_order_item_that_was_removed_from_cart
    order.order_items.delete_if {|order_item| !items_in_cart.keys.any?{|variant_id| variant_id == order_item.variant_id } }
   # order.order_items.delete_all #destroy(order_item.id)

    items = order.order_items.inject({}) {|h, item| h[item.variant_id].nil? ? h[item.variant_id] = [item.id]  : h[item.variant_id] << item.id; h}

    items_in_cart.each_pair do |variant_id, qty_in_cart|
      if items[variant_id].nil?
        variant = Variant.find(variant_id)
        order.add_items( variant , qty_in_cart)
      elsif qty_in_cart - items[variant_id].size > 0
        order.add_items( variant , qty - items[variant_id])
      elsif qty_in_cart - items[variant_id].size < 0
        order.remove_items( variant , qty_in_cart - items[variant_id])
      end
    end
  end
end
