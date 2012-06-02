require 'json/add/rails'
require 'open-uri'
require 'yaml'
require 'date'
require 'Obp_transactions'
YAML::ENGINE.yamler = 'syck'

class ApireaderController < ApplicationController
  def index
    file_handle = open("https://demo.openbankproject.com/api/accounts/tesobe/anonymous")
    transactions = ActiveSupport::JSON.decode(file_handle)
    tr = nil
    
    transactions.each do |transaction|
      tp=TransactionPartner.new(:account_holder =>transaction["obp_transaction"]["other_account"]["holder"]["holder"],:bank_name => "Bank")
      tp.save

      transaction_date = transaction["obp_transaction"]["details"]["completed"]
      d = Date.strptime(transaction_date, '%Y-%m-%d')    
      td = TransactionDate.new(:day => d.mday, :month => d.mon, :year => d.year)
      td.save
      
      amount = transaction["obp_transaction"]["details"]["value"]["amount"]
      cat = Category.new(:category_name => get_category(tp.account_holder), :category_type => get_category_type(amount))
      cat.save
      holder = transaction["obp_transaction"]["this_account"]["holder"]["holder"]
      
      tr = Transaction.new(:account_holder => holder, :amount => amount.abs)
      tr.category_id = cat.id
      tr.transaction_date_id = td.id
      tr.transaction_partner_id = tp.id
      tr.save
    end 
  end
  def read_categorization_files
    root_dir = Rails.root.to_s + '/Categorisation/*'
    cat_files = Dir.glob(root_dir)
    @cats = Hash.new
    cat_files.each do |file|
      cat = file.split("/").last
      File.open(file, "r").each_line do |line|
        holder = line.delete("\n")
        @cats[holder] = cat unless holder.empty?
      end
    end
  end
  
  def get_category(account_holder)
    root_dir = Rails.root.to_s + '/Categorisation/*'
    cat_files = Dir.glob(root_dir)
    @cats = Hash.new
    cat_files.each do |file|
      cat = file.split("/").last
      File.open(file, "r").each_line do |line|
        holder = line.delete("\n")
        @cats[holder] = cat unless holder.empty?
      end
    end
    

    if @cats[account_holder].nil?
      return "others"
    else
      return @cats[account_holder]
    end
  end
  
  def get_category_type(amount)
    
    if amount.to_i > 0
      return "income"
    else
      return "expense"
    end
  end

  def index2
	data = Array.new

	expenses = Transaction.find_by_sql("SELECT sum(amount) as expenses FROM transactions WHERE amount < 0").first.expenses
	data << _get_data_item("Expenses", expenses)

	income = Transaction.find_by_sql("SELECT sum(amount) as income FROM transactions WHERE amount > 0").first.income
	data << _get_data_item("Income", income)

  categories = Category.find(:all)

  categories.each do |category|
    if category.parent then
      sum = 0
      category.transactions.each do |transaction|
        sum += transaction.amount
      end

      data << _get_data_item(category.category_name, sum, category.parent.category_name)
    end
  end

	respond_to do |format|
	  format.json { render :json => data }
	end
end

  protected

  def _get_data_item(name, volume, parent = nil)
  	volume ||= 0
  	data_item = Hash.new
  	data_item[:name]   = name
  	data_item[:volume] = volume.to_i.abs
  	data_item[:parent] = parent
  	data_item[:heat]   = 0
  	data_item
  end

end
