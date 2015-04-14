require 'httparty'
require 'json'
require 'base64'
require 'hashie'

begin
  require 'byebug'
rescue LoadError
end

class Bitfinex
  module OrderTypes
    module Market; end
    module Limit; end
    module Stop; end
    module TrailingStop; end
    module ExchangeMarket; end
    module ExchangeLimit; end

    module ExchangeStop; end
    module ExchangeTrailingStop; end
  end
end

class Order

end

class Bitfinex
  include HTTParty
  base_uri 'https://api.bitfinex.com'
  format :json

  def initialize(key=nil, secret=nil)
    @debug = true if ENV['DEBUG']
    @key = key
    @secret = secret
    unless have_key?
      begin
        cfg_file = File.join(File.dirname(__FILE__), '..',
                             'config', 'api.yml')
        api = YAML.load_file(cfg_file)
        @key = api['key']
        @secret = api['secret']
      rescue
      end
    end
    @exchanges = ["BFX", "BSTP", "all"] # all = no routing
    @ticker_info = nil
    #@orders = {}
    @buy_orders = {}
    @sell_orders = {}
  end

  def buxs(amount)
    "%8.02f" % amount.to_f
  end

  def flts(amount)
    "%10.06f" % amount
  end

  def have_key?
    # validate access & memoize
    @key && @secret
  end

  def headers_for(url, options={})
    payload = {}
    payload['request'] = url
    # nonce needs to be a string, server error is wrong
    payload['nonce'] = (Time.now.to_f * 10000).to_i.to_s
    payload.merge!(options)

    payload_enc = Base64.encode64(payload.to_json).gsub(/\s/, '')
    digest = OpenSSL::Digest.new('sha384')
    sig = OpenSSL::HMAC.hexdigest(digest, @secret, payload_enc)

    { 'Content-Type' => 'application/json',
      'Accept' => 'application/json',
      'X-BFX-APIKEY' => @key,
      'X-BFX-PAYLOAD' => payload_enc,
      'x-BFX-SIGNATURE' => sig}
  end

  # --------------- authenticated -----------------
  def orders
    return nil unless have_key?
    url = "/v1/orders"
    self.class.post(url, :headers => headers_for(url)).parsed_response
  end

  def positions
    return nil unless have_key?
    url = "/v1/positions"
    pos = self.class.post(url, :headers => headers_for(url)).parsed_response
    raise "Error fetching positions" unless pos.class == Array
    pos.each { |psn|
      %w(base amount timestamp swap pl).each { |kk|
        psn[kk] = psn[kk].to_f
      }
      psn['id'] = psn['id'].to_i
      psn['timestamp'] = Time.at(psn['timestamp'])
    }
    #Hashie::Mash.new(pos)
    pos
  end

  # requests for credit and offers that haven't been accepted
  def offers
    return nil unless have_key?
    url = "/v1/offers"
    #Hashie::Mash.new(
      self.class.post(url, :headers => headers_for(url)).parsed_response
  end

  # credit extended to others
  def credits
    return nil unless have_key?
    url = "/v1/credits"
    #Hashie::Mash.new(
      self.class.post(url, :headers => headers_for(url)).parsed_response
  end

  def balances
    return nil unless have_key?
    url = "/v1/balances"
    #Hashie::Mash.new(
      self.class.post(url, :headers => headers_for(url)).parsed_response
  end

  def transfer(opts={})
    return nil unless have_key?
    url = "/managewallets/create"
    topts = {actionwallet:'TRANSFER',
          amount:1.00,
          currency:'USD',
          walletfrom:'exchange',
          walletto:'trading'}.merge(opts)
    #begin
    self.class.post(url, :headers => headers_for(url, topts)).parsed_response
  end

  # I have to give this method such name because 'history' is already occupied :/
  # refactoring will break backward compatibility
  def balance_history(opts={})
    return nil unless have_key?
    url = "/v1/history"
    ho = {currency:'usd', limit: 500}.merge(opts)
    options = {
        'currency' => ho[:currency],
        'limit' => ho[:limit]
    }
    begin

      resp = self.class.post(url, :headers => headers_for(url, options)).parsed_response
    rescue => e
      puts e
    end

    resp
  end

  def history_movements(opts={})
    return nil unless have_key?
    url = "/v1/history/movements"
    ho = {currency:'usd'}.merge(opts)
    options = {
        :currency => ho[:currency]
    }
    %w(method since until limit).each { |optional_argument|
      unless opts[optional_argument.to_sym].nil?
        options[optional_argument] = opts[optional_argument.to_sym]
      end
    }
    begin
      resp = self.class.post(url, :headers => headers_for(url, options)).parsed_response
    rescue => e
      puts e
    end

    resp
  end

  def history(opts={})
    return nil unless have_key?
    url = "/v1/mytrades"
    ho = {sym:'btcusd', limit:9100, start:0, reverse:false}.merge(opts)
    options = {
      'symbol' => ho[:sym],
      'timestamp' => ho[:start],
      'limit_trades' => ho[:limit]
    }
    hist = []
    begin
      resp = self.class.post(url, :headers => headers_for(url, options)).parsed_response
      resp.each { |tx|
        txm = Hashie::Mash.new(tx)
        %w(price amount timestamp fee_amount).each { |kk|
          txm[kk] = tx[kk].to_f
        }
        txm.timestamp = Time.at(txm.timestamp.to_f)
        txm.time = txm.timestamp.strftime("%Y%m%d %H:%M:%S")
        hist << txm
      }
    rescue => e
      puts e
    end
    hist.reverse! if opts[:reverse]
    hist
  end

  def history_all
    {:btcusd => history('btcusd'),
     :ltcusd => history('ltcusd'),
     :ltcbtc => history('ltcbtc')}
  end

  def status(order_id)
    return nil unless have_key?
    #return @orders[order_id] if @orders[order_id] && (Time.now - @orders[order_id].timestamp < 10)
    url = "/v1/order/status"
    oid = order_id.to_i
    options = {
      'order_id' => oid
    }
    response = self.class.post(url, :headers => headers_for(url, options)).parsed_response
    %w(price avg_execution_price timestamp
       original_amount remaining_amount executed_amount).each { |kk|
      response[kk] = response[kk].to_f
    }
    response['timestamp'] = Time.at(response['timestamp'])
    om = Hashie::Mash.new(response)

    if !@buy_orders[om.order_id] && !@sell_orders[om.order_id]
      # haven't seen this order before
      if om.side == 'buy'
        @buy_orders[oid] = om
      elsif om.side == 'sell'
        @sell_orders[oid] = om
      else
        raise "order #{oid} has side #{om.side} not buy or sell"
      end
    end

    om
  end

  def cancel(order_ids)
    return nil unless have_key?

    ids = [order_ids].flatten
    case
    when ids.length < 1
      return true
    when ids.length == 1
      url = "/v1/order/cancel"
      options = {
        "order_id" => ids[0].to_i
      }
    when ids.length > 1
      url = "/v1/order/cancel/multi"
      options = {
        "order_ids" => "#{ids.join(',')}"
      }
    end

    Hashie::Mash.new(
      self.class.post(url, :headers => headers_for(url, options)).parsed_response
    )
  end

  def sell_bstp(amount, price=nil, opts={})
    sell(amount, price, opts.merge({side:'sell', routing: 'bitstamp'}))
  end

  def sell_bfx(amount, price=nil, opts={})
    sell(amount, price, opts.merge({side:'sell', routing: 'bitfinex'}))
  end

  def sell(amount, price=nil, opts={})
    oh = {side: 'sell', routing: 'all', type: 'limit', hide: false}.merge(opts)
    order(amount, price, oh)
  end

  def sell_x(amount, price=nil, opts={})
    oh = {side: 'sell', routing: 'all', type: 'exchange limit', hide: false}.merge(opts)
    order(amount, price, oh)
  end

  def buy_bstp(amount, price=nil, opts={})
    buy(amount, price, opts.merge({side:'buy', routing: 'bitstamp'}))
  end

  def buy_bfx(amount, price=nil, opts={})
    buy(amount, price, opts.merge({side:'buy', routing: 'bitfinex'}))
  end

  def buy(amount, price=nil, opts={})
    oh = {side: 'buy', routing: 'all', type: 'limit', hide: false}.merge(opts)
    order(amount, price, oh)
  end

  def buy_x(amount, price=nil, opts={})
    puts "Bitfinex.buy_x(#{amount}, #{price}}"
    oh = {side: 'buy', routing: 'all', type: 'exchange limit', hide: false}.merge(opts)
    order(amount, price, oh)
  end


  def withdraw(amount, address, type = 'bitcoin', wallet = 'exchange')
    return nil unless have_key?
    url = "/v1/withdraw"

    options = {
        withdraw_type: type,
        walletselected: wallet,
        amount:amount.to_s,
        address: address
    }

    puts "withdraw(): options:#{options}" if @debug

    begin
      res = self.class.post(url, :headers => headers_for(url, options))

      unless res.response.code == '200'
        # Server error
        msg = "Server returned #{res.response.code}"
        msg = res.parsed_response['message'] if res.parsed_response['message']
        raise  msg
      end

      # This complex check is required while response content is not fixed
      if (res.parsed_response.kind_of?(Array) && res.parsed_response[0]['status'] == 'error') || (!res.parsed_response.kind_of?(Array) && res.parsed_response['status'] == 'error')
        # Error in request parameters
        raise (defined? res.parsed_response[0]['status']) ? res.parsed_response[0]['status'] : res.parsed_response['status']
      end
    rescue => e
      raise "Error submitting withdraw request: #{e}"
    end

    res.parsed_response
  end


  def order(amount, price=nil, opts={})
    return nil unless have_key?
    url = "/v1/order/new"

    oh = {type:'limit', sym:'btcusd', routing:'all', side:'buy'}.merge(opts)
    puts "order(): oh:#{oh}" if @debug
    #byebug
    # using negative amounts as shorthand for a sell
    if amount < 0
      puts "order(): negative amount: #{amount}" if @debug
      amount = amount.abs.to_s
      #oh[:side] = 'sell'
    end

    order = {
      'symbol' => oh[:sym],
      'amount' => amount.to_s,
      'exchange' => oh[:routing],
      'side' => oh[:side],
      'type' => oh[:type]
    }

    unless price
      # no price if market order
      order['type'] = 'market'
    else
      # raise "price specified but order type set to market"
      order[:price] = price.to_s unless oh[:type] == 'market'
    end

    order['is_hidden'] = true if oh[:hide]

    begin
      res = self.class.post(url, :headers => headers_for(url, order))
      unless res.response.code == '200'
        msg = "Server returned #{res.response.code}"
        msg = res.parsed_response['message'] if res.parsed_response['message']
        raise  msg
      end
    rescue => e
      raise "Error submitting order: #{e}"
    end
    om = Hashie::Mash.new(res.parsed_response)
    if @buy_orders[om.order_id] || @sell_orders[om.order_id]
      raise "order id already present: #{om.order_id}"
      byebug
      puts
    else
      if om.side == 'sell'
        @sell_orders[om.order_id] = om
      elsif om.side == 'buy'
        @buy_orders[om.order_id] = om
      else
        raise "invalid side: #{om.side}"
        byebug
        puts
      end
    end
  end

  def summarize_orders(orderids=[])
    #begin
      puts "summary for #{orderids.length} order(s)\n(#{orderids.join(', ')})" if @debug
      btc_buy = 0.0
      price_buy = 0.0
      price_buy_avg = 0.0
      btc_sell = 0.0
      price_sell = 0.0
      price_sell_avg = 0.0
      fees = 0.0
      fee = 0.0
      pending_buy = 0.0
      pending_sell = 0.0
      summary_side = '+'

      os = []
      orderids.each { |oo|
        # XXX: check symbol and currency pair
        # XXX: memoize
        #if @orders[oo] && Time.now - @orders[oo].timestamp < 10
        #  oi = @orders[oo]
        #else
          oi = Hashie::Mash.new(status(oo))
        #end
        cost = oi.executed_amount * oi.avg_execution_price
        fee = cost * 0.0035 if oi.exchange == 'bitstamp'
        fee = cost * 0.0015 if oi.exchange == 'bitfinex'
        fees += fee

        if oi.side == 'buy'
          pending_buy += oi.remaining_amount
          btc_buy += oi.executed_amount
          price_buy += cost
          summary_side = '-'
        elsif oi.side == 'sell'
          pending_sell += oi.remaining_amount
          btc_sell += oi.executed_amount
          price_sell += cost
        else
          puts "invalid oi.side: #{oi.side}"
          byebug
        end
        os << "Order #{oo} #{summary_side}#{buxs(cost)} (fee: #{buxs(fees)})"
      }
      price_buy_avg = price_buy/btc_buy
      price_sell_avg = price_sell/btc_sell

      os << "  Total #{flts(btc_buy)} bought for ~$#{buxs(price_buy)} (#{buxs(price_buy/btc_buy)}/BTC)"  if btc_buy > 0
      os << "  Total #{flts(btc_sell)}  sold for ~$#{buxs(price_sell)} (#{buxs(price_sell/btc_sell)}/BTC)" if btc_sell > 0
      #os << "  Pending: #{pending_buy} buy @ #{buxs(price_buy)} avg" #if pending_buy > 0
      os << "  Pending: #{pending_buy} buy / #{pending_sell} sell "
      #os << "           #{pending_sell} sell @ #{buxs(price_sell)} avg" #if pending_sell > 0
      os << "  Current: #{ticker.bid} bid #{ticker.ask} ask"
      os << "  Total fees: #{"%06.02f" % fees}" if fees > 0
      if btc_buy > 0 && btc_sell > 0
        total_btc = btc_buy - btc_sell
        total_price = price_sell - price_buy - fees
        os << "  Net #{total_price} (#{total_btc} remaining)"
      end
      return os.join("\n")
    #rescue => e
      #byebug
      #raise "Summary unavailable: #{e}"
      #retry
    #end
  end

  # --------------- unauthenticated -----------------
  def ticker(sym='btcusd', options={})
    return @ticker_info if @ticker_info && Time.now - @ticker_info.timestamp < 60
    #with_retries(:max_tries => 3) {
      tick = Hashie::Mash.new(self.class.get("/v1/ticker/#{sym}", options).parsed_response)
      tick.keys.each { |kk|
        tick[kk] = tick[kk].to_f
      }
      tick['timestamp'] = Time.at(tick['timestamp'])
      @ticker_info = tick
    #}
  end

  # documented, but not available
  def today(sym='btcusd', options={})
    #Hashie::Mash.new(self.class.get("/v1/today/#{sym}", options).parsed_response)
    nil
  end

  # documented, but not available
  def candles(sym='btcusd', options={})
    #Hashie::Mash.new(
    #self.class.get("/v1/candles/#{sym}", options).parsed_response
    nil
  end

  #
  def orderbook(opts={})
    oo = {sym:'btcusd', limit_bids:50, limit_asks:50}.merge(opts)
    # {"bids" => [bid, bid, ...], "ask": [ ask, ask, ...]}
    options = {
      "limit_bids" => oo[:limit_bids],
      "limit_asks" => oo[:limit_asks]
    }
    url = "/v1/book/#{oo[:sym]}"
    Hashie::Mash.new(
      (self.class.get(url, :headers => headers_for(url, options)).parsed_response))
  end

  def lendbook(sym='btc', opts={})
    url="/v1/lendbook/#{sym}"
    options={limit_bids:1000, limit_asks:1000}.merge(opts)
    #Hashie::Mash.new()
    (self.class.get(url, :headers => headers_for(url, options)).parsed_response)
  end

  def trades(opts={})
    to = {sym:'btcusd', limit:50, timestamp:0}.merge(opts)
      options = {
        "limit" => to[:limit].to_i,
        "timestamp" => to[:timestamp].to_s
      }
    # XXX: save to local storage
    begin
      tr = []
       url = "/v1/trades/#{to[:sym]}"
      (self.class.get(url, :headers => headers_for(url, options)).parsed_response).each { |th|
        tm = Hashie::Mash.new(th)
        tm.price = tm.price.to_f
        tm.timestamp = tm.timestamp
        tm.amount = tm.amount.to_f
        tm.time = Time.at(tm.timestamp.to_f).strftime("%H:%M:%S")
        tr << tm
      }
      return tr.reverse
    rescue => e
      puts "Bitfinex.trades error:#{e}"
    end
  end

  def lends(sym='btc')
    #Hashie::Mash.new(
    self.class.get("/v1/lends/#{sym}").parsed_response
  end

  def symbols()
    #Hashie::Mash.new(
    self.class.get("/v1/symbols").parsed_response
  end
end

if __FILE__ == $0
  bfx = Bitfinex.new
  #puts bfx.lendbook
  #puts bfx.orderbook

  #puts bfx.lends
  #puts bfx.trades
  #puts bfx.symbols
  #puts bfx.ticker
  #puts bfx.today
  #puts bfx.candles

  puts bfx.balances
  puts bfx.transfer
  puts bfx.balances

  #puts bfx.status(4627020)
  #puts bfx.cancel(4627020)
  #puts bfx.status(4627020)
  #puts bfx.order(0.001, 500)
end


