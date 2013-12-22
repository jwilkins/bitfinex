require 'httparty'
require 'json'
require 'digest/sha2'
require 'digest/hmac'
require 'base64'

class BitFinex
  include HTTParty
  base_uri 'https://api.bitfinex.com/v1'
  #debug_output

  def initialize(key=nil, secret=nil)
    @key = key
    @secret = secret
    unless @key && @secret
      begin
        cfg_file = File.join(File.dirname(__FILE__), '..',
                             'config', 'api.yml')
        api = YAML.load_file(cfg_file)
        if api['key'] && api['secret']
          @key = api['key']
          @secret = api['secret']
        end
      rescue
      end
    end

    @authenticated_api = @key && @secret
  end

  def headers_for(url, options={})
    payload = {}
    payload['request'] = url
    # nonce needs to be a string, server error is wrong
    payload['nonce'] = Time.now.to_i.to_s
    payload['options'] = options

    payload_enc = Base64.encode64(payload.to_json).gsub(/\s/, '')
    sig = Digest::HMAC.hexdigest(payload_enc, @secret, Digest::SHA384)

    { 'X-BFX-APIKEY' => @key,
      'X-BFX-PAYLOAD' => payload_enc,
      'x-BFX-SIGNATURE' => sig}
  end

  # --------------- authenticated -----------------
  def balances
    url = "/v1/balances"
    self.class.post(url, :headers => headers_for(url))
  end

  # --------------- unauthenticated -----------------
  def ticker(sym='btcusd', options={})
    self.class.get("/ticker/#{sym}", options)
  end

  # documented, but not available
  def today(sym='btcusd', options={})
    self.class.get("/today/#{sym}", options)
  end

  def candles(sym='btcusd', options={})
    self.class.get("/candles/#{sym}", options)
  end

  def orderbook(sym='btcusd')
    self.class.get("/book/#{sym}")
  end

  def lendbook(sym='btc')
    self.class.get("/lendbook/#{sym}")
  end

  def trades(sym='btcusd')
    self.class.get("/trades/#{sym}")
  end

  def lends(sym='btc')
    self.class.get("/lends/#{sym}")
  end

  def symbols()
    self.class.get("/symbols")
  end
end

if __FILE__ == $0
bfx = BitFinex.new
puts bfx.lendbook
puts bfx.orderbook

#puts bfx.lends
#puts bfx.trades
#puts bfx.symbols
#puts bfx.ticker
#puts bfx.today
#puts bfx.candles

#puts bfx.balances
end


