require 'bitcoin-client'
Dir['./coin_config/*.rb'].each {|file| require file }
require './bitcoin_client_extensions.rb'
class Command
  attr_accessor :result, :action, :user_name, :icon_emoji
  ACTIONS = %w(balance deposit tip withdraw networkinfo help)
  def initialize(slack_params)
    @coin_config_module = Kernel.const_get ENV['COIN'].capitalize
    text = slack_params['text']
    @params = text.split(/\s+/)
    raise "I do not understand that command. Try 'help'" unless @params.shift == slack_params['trigger_word']
    @user_name = slack_params['user_name']
    @user_id = slack_params['user_id']
    @action = @params.shift
    @result = {}
  end

  def perform
    if ACTIONS.include?(@action)
      self.send("#{@action}".to_sym)
    else
      raise @coin_config_module::PERFORM_ERROR
    end
  end

  def client
    @client ||= Bitcoin::Client.local
  end

  def balance
    balance = client.getbalance(@user_id)
    @result[:text] = "@#{@user_name} #{@coin_config_module::BALANCE_REPLY_PRETEXT} #{balance}#{@coin_config_module::CURRENCY_ICON}"
    if balance > @coin_config_module::WEALTHY_UPPER_BOUND
      @result[:text] += @coin_config_module::WEALTHY_UPPER_BOUND_POSTTEXT
      @result[:icon_emoji] = @coin_config_module::WEALTHY_UPPER_BOUND_EMOJI
    elsif balance > 0 && balance < @coin_config_module::WEALTHY_UPPER_BOUND
      @result[:text] += @coin_config_module::BALANCE_REPLY_POSTTEXT
    end

  end

  def deposit
    @result[:text] = "#{@coin_config_module::DEPOSIT_PRETEXT} #{user_address(@user_id)} #{@coin_config_module::DEPOSIT_POSTTEXT}\n"
    @result[:attachments] = [{
      image_url: "#{@coin_config_module::ADDRESS_QR}#{user_address(@user_id)}"
      }]
  end

  def tip
    user = @params.shift
    userBalance = client.getbalance(@user_id)
    #targetBalance = client.getbalance(target_user)
    raise @coin_config_module::TIP_ERROR_TEXT unless user =~ /<@(U.+)>/

    target_user = $1
    set_amount
    targetBalance = client.getbalance(target_user)
    tx = client.sendfrom @user_id, user_address(target_user), @amount
    @result[:text] = "#{@coin_config_module::TIP_PRETEXT} <@#{@user_id}> => <@#{target_user}> #{@amount}#{@coin_config_module::CURRENCY_ICON}"
    @result[:attachments] = [{
      fallback:"<@#{@user_id}> tipped <@#{target_user}> #{@amount}:SKC:",
      color: "good",
      author_name: "SecKCoin Bank and Trust",
      footer: "Please note: Transactions require at least one block confirmation in order to appear (Up to 5 minutes)",
      fields: [{
        title: ":skc: Transaction Hash:",
        value: "#{tx}",
        short: false
      },{
        title: "From: ",
        value: "<@#{@user_id}>\n<#{@coin_config_module::ADDRESS_LOOKUP}#{user_address(@user_id)}|#{user_address(@user_id)}>\nCurrent Balance: #{userBalance}",
        short: true
      },{
        title: "To: ",
        value: "<@#{target_user}>\n<#{@coin_config_module::ADDRESS_LOOKUP}#{user_address(target_user)}|#{user_address(target_user)}>\nCurrent Balance: #{targetBalance}",
        short: true
      }]
    }]
    #
    @result[:text] += " (View transaction on <#{@coin_config_module::TIP_POSTTEXT1}#{tx}|https://seckco.in>)"
  end

  alias :":tipskc:" :tip

  def withdraw
    address = @params.shift
    set_amount
    tx = client.sendfrom @user_id, address, @amount
    @result[:text] = "#{@coin_config_module::WITHDRAW_TEXT} <@#{@user_id}> => #{address} #{@amount}#{@coin_config_module::CURRENCY_ICON} "
    @result[:text] += " \n(View transaction on <#{@coin_config_module::TIP_POSTTEXT1}#{tx}|https://seckco.in>)"
    @result[:icon_emoji] = @coin_config_module::WITHDRAW_ICON
  end

  def networkinfo
    info = client.getinfo
    @result[:text] = info.to_s
    @result[:icon_emoji] = @coin_config_module::NETWORKINFO_ICON
  end

  private

  def set_amount
    amount = @params.shift
    if (amount == "random")
        lower = @params.shift.to_i
        upper = @params.shift.to_i
        @amount = rand(lower..upper).to_i
    else 
        @amount = amount.to_f
    end

  
    
    raise @coin_config_module::TOO_POOR_TEXT unless available_balance >= @amount + 1
    raise @coin_config_module::NO_PURPOSE_LOWER_BOUND_TEXT if @amount < @coin_config_module::NO_PURPOSE_LOWER_BOUND
  end

  def randomize_amount
    lower = [1, @params.shift.to_i].min
    upper = [@params.shift.to_i, available_balance].max
    @amount = rand(lower..upper)
    @result[:icon_emoji] = @coin_config_module::RANDOMIZED_EMOJI
  end

  def available_balance
     client.getbalance(@user_id)
  end

  def user_address(user_id)
     existing = client.getaddressesbyaccount(user_id)
    if (existing.size > 0)
      @address = existing.first
    else
      @address = client.getnewaddress(user_id)
    end
  end

  def help
    
    @result[:text] = "#{@coin_config_module::HELP_TEXT} #{ACTIONS.join(', ' )}"
    @result[:attachments] = [{
      color: "good",
      fields: [{
        title: ":skc: How-To get Started:",
        value: "http://coin.seckc.org",
        short: false
      },{
        title: "Bot Commands:",
      },{
        title: "balance:",
        value: "Usage tipskc balance -- This will show your your current :skc: balance",
        short: false
      },{
        title: "deposit:",
        value: "Usage 'tipskc deposit' -- This will return your :SKC: wallet address",
        short: false        
      },{
        title: "tip:",
        value: "Usage 'tipskc tip @username amount' -- This will transfer the specified amount of :skc: to the other user. Also available 'tipskc tip @username random low high'",
        short: false 
      },{
        title: "withdraw:",
        value: "Usage 'tipskc withdraw SecKCoinAddress amount' -- This will transfer :SKC: from the bot wallet to whatever address you specify (ex a Desktop wallet)",
        short: false  
      },{
        title: "networkinfo:",
        value: "Usage 'tipskc networkinfo' -- This will return information about the SecKCoin network",
        short: false 
      },{
        title: "help:",
        value: "Usage 'tipskc help' -- this will return this text",
      }]
    }]
  end

end
