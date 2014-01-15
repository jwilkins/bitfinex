$: << File.join(File.dirname(__FILE__), '..', 'lib')
$: << File.join(File.dirname(__FILE__))

require 'bitfinex'
require 'byebug'
require 'knock'

include Knock

testing "Authenticated calls" do
  @bfx = Bitfinex.new

  testing 'orders' do
    orders = @bfx.orders
    isnt orders, nil, "orders isn't nil"
    ok bal.class == Array, "orders is an array"
  end

  testing 'positions' do
    positions = @bfx.positions
    isnt positions, nil, "positions isn't nil"
    ok positions.class == Array, "positions is an array"
    if positions.length > 0
      ok positions.first['id'].class == Integer, "position entry has an id key, value integer"
    end
  end

  testing 'offers' do
    offers = @bfx.offers
    isnt offers, nil, "offers isn't nil"
    ok offers.class == Array, "offers is an array"
  end

  testing 'credits' do
    credits = @bfx.credits
    isnt credits, nil, "credits isn't nil"
    ok credits.class == Array, "credits is an array"
  end

  testing 'balances' do
    bal = @bfx.balances
    ok bal.length > 1, "balances is array"
    isnt bal.first['type'], nil, "balance has type field"
  end
end
