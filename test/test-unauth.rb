$: << File.join(File.dirname(__FILE__), '..', 'lib')
$: << File.join(File.dirname(__FILE__))

require 'bitfinex'
require 'byebug'
require 'knock'

include Knock

testing "Unauthenticated calls" do
  @bfx = BitFinex.new

  testing "foo" do
    pass
  end

  testing 'symbols' do
    ok @bfx.symbols.sort == %w(btcusd ltcbtc ltcusd).sort
  end

  testing "ticker" do
    isnt @bfx.ticker('btcusd')['mid'], nil
  end

  testing "candles" do
    res = @bfx.candles('btcusd')
    puts res
    isnt res, nil
  end

  testing "orderbook" do
    res = @bfx.orderbook('btcusd')
    puts res
    isnt res, nil
  end

  testing "lendbook" do
    res = @bfx.lendbook('btc')
    puts res
    isnt res, nil
  end

  testing "lends" do
    res = @bfx.lends('btcusd')
    puts res
    isnt res, nil
  end

  testing "trades" do
    res = @bfx.trades('btcusd')
    puts res
    isnt res, nil
  end
end
