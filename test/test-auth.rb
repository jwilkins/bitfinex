$: << File.join(File.dirname(__FILE__), '..', 'lib')
$: << File.join(File.dirname(__FILE__))

require 'bitfinex'
require 'byebug'
require 'knock'

include Knock

testing "Authenticated calls" do
  @bfx = BitFinex.new

  testing 'orders' do
    orders = @bfx.orders
    puts orders
  end

  testing 'positions' do
    positions = @bfx.positions
    puts positions
  end

  testing 'offers' do
    offers = @bfx.offers
    puts offers
  end

  testing 'credits' do
    credits = @bfx.credits
    puts credits
  end

  testing 'balances' do
    bal = @bfx.balances
    ok bal.length > 1, "balances is array"
    isnt bal.first['type'], nil, "balance has type field"
  end
end
