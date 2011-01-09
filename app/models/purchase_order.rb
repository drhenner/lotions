class PurchaseOrder < ActiveRecord::Base
  belongs_to :supplier

  has_many  :purchase_order_variants
  has_many  :variants, :through => :purchase_order_variants

  has_many  :batches,             :as => :batchable
  has_many  :transaction_ledgers, :as => :accountable

  validates :invoice_number,  :presence => true, :length => { :maximum => 200 }
  validates :ordered_at,      :presence => true
  validates :total_cost,      :presence => true
  #validates :is_received,     :presence => true

  accepts_nested_attributes_for :purchase_order_variants,
                                :reject_if      => lambda { |attributes| attributes['cost'].blank? && attributes['quantity'].blank? },
                                :allow_destroy  => true

  INCOMPLETE  = 'incomplete'
  PENDING     = 'pending'
  RECEIVED    = 'received'
  STATES      = [PENDING, INCOMPLETE, RECEIVED]

  state_machine :state, :initial => :pending do
    state :pending
    state :incomplete
    state :received

    after_transition :on => :complete, :do => [:pay_for_order, :receive_variants]

    event :complete do |purchase_order|
      transition all => :received
    end

    event :mark_as_complete do
      transition all => :received
    end
  end

  # in the admin form this is the method called when the form is submitted, The method sets
  # the PO to complete, pays for the order in the accounting peice and adds the inventory to stock
  #
  # @param [String] value for set_keywords in a products form
  # @return [none]
  def receive_po=(answer)

    if (answer == 'true' || answer == '1') && (state != RECEIVED)
      complete!
    end
  end

  # in the admin form this is the method called when the form is created, The method
  # determines if the order has already been received
  #
  # @return [Boolean]
  def receive_po
    (state == RECEIVED)
  end

  # called by state machine after the PO is complete.  adds the inventory to stock
  #
  # @param [none]
  # @return [none]
  def receive_variants
    po_variants = PurchaseOrderVariant.where(:purchase_order_id => self.id).find(:all, :lock => "LOCK IN SHARE MODE")
    po_variants.each do |po_variant|
      po_variant.receive! unless po_variant.is_received?
    end
  end

  # returns "Yes" if the PO has been received, otherwise "No"
  #
  # @param [none]
  # @return [String]  "Yes" or "No"
  def display_received
    (state == RECEIVED) ? 'Yes' : 'No'
  end

  def display_estimated_arrival_on
    estimated_arrival_on? ? estimated_arrival_on.to_s(:format => :us_date) : ""
  end

  # returns "the tracking #" if the tracking # exists, otherwise "N/A"
  #
  # @param [none]
  # @return [String]  "Yes" or "No"
  def display_tracking_number
    tracking_number? ? tracking_number : 'N/A'
  end

  # returns "Suppliers name" if the supplier exists, otherwise "N/A"
  #
  # @param [none]
  # @return [String]  "Yes" or "No"
  def supplier_name
    supplier.name rescue 'N/A'
  end

  def pay_for_order
    now = Time.zone.now
    if self.batches.empty?
      # this means we never authorized just captured payment
        batch = self.batches.create()
        transaction = ReceivePurchaseOrder.new()##  This is a type of transaction
        credit = self.transaction_ledgers.new(:transaction_account_id => TransactionAccount::CASH_ID,     :debit => 0,      :credit => total_cost, :period => "#{now.month}-#{now.year}")
        debit  = self.transaction_ledgers.new(:transaction_account_id => TransactionAccount::EXPENSE_ID, :debit => total_cost, :credit => 0,      :period => "#{now.month}-#{now.year}")
        transaction.transaction_ledgers.push(credit)
        transaction.transaction_ledgers.push(debit)
        batch.transactions.push(transaction)
        batch.save
    else
      batch       = batches.first
      transaction = ReceivePurchaseOrder.new()

      debit   = self.transaction_ledgers.new(:transaction_account_id => TransactionAccount::EXPENSE_ID, :debit => total_cost, :credit => 0,       :period => "#{now.month}-#{now.year}")
      credit  = self.transaction_ledgers.new(:transaction_account_id => TransactionAccount::CASH_ID,    :debit => 0,      :credit => total_cost,  :period => "#{now.month}-#{now.year}")

      transaction.transaction_ledgers.push(credit)
      transaction.transaction_ledgers.push(debit)

      batch.transactions.push(transaction)
      batch.save
    end
  end

  # paginated results from the admin PurchaseOrder grid
  #
  # @param [Optional params]
  # @return [ Array[PurchaseOrder] ]
  def self.admin_grid(params = {})

    params[:page] ||= 1
    params[:rows] ||= SETTINGS[:admin_grid_rows]

    grid = PurchaseOrder.includes(:supplier)
    grid = grid.where("suppliers.name = ?",                  params[:name])            if params[:name].present?
    grid = grid.where("purchase_orders.invoice_number = ?",  params[:invoice_number])  if params[:invoice_number].present?
    grid = grid.where("purchase_orders.tracking_number = ?", params[:tracking_number]) if params[:tracking_number].present?

    grid = grid.order("#{params[:sidx]} #{params[:sord]}")
    grid = grid.limit(params[:rows])
    grid.paginate({:page => params[:page]})
  end

  # paginated results from the admin PurchaseOrder grid for PO to receive
  #
  # @param [Optional params]
  # @return [ Array[PurchaseOrder] ]
  def self.receiving_admin_grid(params = {})

    params[:page] ||= 1
    params[:rows] ||= SETTINGS[:admin_grid_rows]

    grid = PurchaseOrder.where(['purchase_orders.state != ?', PurchaseOrder::RECEIVED])#.where("suppliers.name = ?", params[:name])
    grid = grid.where("suppliers.name = ?",                  params[:name])            if params[:name].present?
    grid = grid.where("purchase_orders.invoice_number = ?",  params[:invoice_number])  if params[:invoice_number].present?
    grid = grid.where("purchase_orders.tracking_number = ?", params[:tracking_number]) if params[:tracking_number].present?

    grid = grid.order("#{params[:sidx]} #{params[:sord]}")
    grid.includes([:supplier, :purchase_order_variants]).paginate({:page => params[:page],:per_page => params[:rows]})

  end
end
