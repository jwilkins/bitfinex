require 'httparty'
require 'json'
require 'digest/sha2'
require 'digest/hmac'
require 'base64'

class BitFinex
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

class BitFinex
  include HTTParty
  base_uri 'https://api.bitfinex.com'
  format :json

  def initialize(key=nil, secret=nil)
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
    sig = Digest::HMAC.hexdigest(payload_enc, @secret, Digest::SHA384)

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
    %w(base amount timestamp swap pl).each { |kk|
      pos[kk] = pos[kk].to_f
    }
    pos['timestamp'] = Time.at(pos['timestamp'])
    pos
  end

  def offers
    return nil unless have_key?
    url = "/v1/offers"
    self.class.post(url, :headers => headers_for(url)).parsed_response
  end

  def credits
    return nil unless have_key?
    url = "/v1/credits"
    self.class.post(url, :headers => headers_for(url)).parsed_response
  end

  def balances
    return nil unless have_key?
    url = "/v1/balances"
    self.class.post(url, :headers => headers_for(url)).parsed_response
  end

  def history(sym='btcusd', limit=9100, start=0)
    return nil unless have_key?
    url = "/v1/mytrades"
    options = {
      'symbol' => sym,
      'timestamp' => start,
      'limit_trades' => limit
    }
    begin
      hist = self.class.post(url, :headers => headers_for(url, options)).parsed_response
      hist.each { |tx|
        tx['timestamp'] = Time.at(tx['timestamp'].to_f).strftime("%Y%m%d %H:%M:%S")
      }
    rescue => e
      puts e
    end
    hist.reverse
  end

  def history_all
    {:btcusd => history('btcusd'),
     :ltcusd => history('ltcusd'),
     :ltcbtc => history('ltcbtc')}
  end

  def status(order_id)
    return nil unless have_key?
    url = "/v1/order/status"
    options = {
      "order_id" => order_id.to_i
    }
    self.class.post(url, :headers => headers_for(url, options)).parsed_response
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

    self.class.post(url, :headers => headers_for(url, options)).parsed_response
  end

  def sell_bstp(amount, price=nil, opts={})
    sell(amount, price, opts.merge({routing: 'bstp'}))
  end

  def sell_bfx(amount, price=nil, opts={})
    sell(amount, price, opts.merge({routing: 'bitfinex'}))
  end

  def sell(amount, price=nil, opts={})
    oh = {side: 'sell', routing: 'all', type: 'limit', hide: false}.merge(opts)
    order(amount, price, oh)
  end

  def buy_bstp(amount, price=nil, opts={})
    buy(amount, price, opts.merge({routing: 'bitstamp'}))
  end

  def buy_bfx(amount, price=nil, opts={})
    buy(amount, price, opts.merge({routing: 'bitfinex'}))
  end

  def buy(amount, price=nil, opts={})
    oh = {side: 'buy', routing: 'all', type: 'limit', hide: false}.merge(opts)
    order(amount, price, oh)
  end

  def order(amount, price=nil, opts={})
    return nil unless have_key?
    url = "/v1/order/new"

    oh = {type:'limit', sym:'btcusd', routing:'all', side:'buy'}.merge(opts)
    # using negative amounts as shorthand for a sell
    if amount < 0
      amount = amount.abs.to_s
      oh[:side] = 'sell'
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

    self.class.post(url, :headers => headers_for(url, order)).parsed_response
  end

  # --------------- unauthenticated -----------------
  def ticker(sym='btcusd', options={})
    tick = self.class.get("/v1/ticker/#{sym}", options).parsed_response
    tick.keys.each { |kk|
      tick[kk] = tick[kk].to_f
    }
    tick['timestamp'] = Time.at(tick['timestamp'])
    tick
  end

  # documented, but not available
  def today(sym='btcusd', options={})
    self.class.get("/v1/today/#{sym}", options).parsed_response
  end

  def candles(sym='btcusd', options={})
    self.class.get("/v1/candles/#{sym}", options).parsed_response
  end

  def orderbook(sym='btcusd')
    self.class.get("/v1/book/#{sym}").parsed_response
  end

  def lendbook(sym='btc')
    self.class.get("/v1/lendbook/#{sym}").parsed_response
  end

  def trades(sym='btcusd')
    self.class.get("/v1/trades/#{sym}").parsed_response
  end

  def lends(sym='btc')
    self.class.get("/v1/lends/#{sym}").parsed_response
  end

  def symbols()
    self.class.get("/v1/symbols").parsed_response
  end
end

if __FILE__ == $0
  require 'byebug'
bfx = BitFinex.new
#puts bfx.lendbook
#puts bfx.orderbook

#puts bfx.lends
#puts bfx.trades
#puts bfx.symbols
#puts bfx.ticker
#puts bfx.today
#puts bfx.candles

#puts bfx.balances
hist = bfx.history('ltcbtc')
puts hist
puts hist.length
open('history-ltcbtc.csv', 'w+'){ |ff|
  ff << "#price, amount, time, exchange, type\n"
  hist.each { |tx|
    ff << "#{tx['price']}, #{tx['amount']}, #{tx['timestamp']}, #{tx['exchange']}, #{tx['type']}\n"
  }
}
exit
puts bfx.status(4627020)
puts bfx.cancel(4627020)
puts bfx.status(4627020)
#puts bfx.order(0.001, 500)
end


