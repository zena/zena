require File.dirname(__FILE__) + '/../../../../../test/test_helper'

class CurrencyTest < Zena::Unit::TestCase
  APP_ID_PATH = File.join(Zena::ROOT, 'config', 'currency_app_id.txt')
  include Bricks::Currency::ViewMethods
  
  if File.exist?(APP_ID_PATH)
    Bricks::Currency.app_id = File.read(APP_ID_PATH).strip
    
    context 'with an app_id' do
      should 'get currencies' do
        list = Bricks::Currency.get_currencies
        assert_equal 'Swiss Franc', list['CHF']
        assert_equal 'Peruvian Nuevo Sol', list['PEN']
        assert_equal 'Euro', list['EUR']
      end
      
      should 'get rates' do
        list = Bricks::Currency.get_rates(%w{EUR CHF USD}, 'CHF')
        eur = list[0]
        chf = list[1]
        usd = list[2]
        
        assert_equal 'CHF',         chf[0]
        assert_equal 1.0,           chf[1]
        assert_equal 'Swiss Franc', chf[2]
        
        assert_equal 'EUR',   eur[0]
        assert_kind_of Float, eur[1]
        assert_equal 'Euro',  eur[2]
        
        assert_equal 'USD',                  usd[0]
        assert_kind_of Float,                usd[1]
        assert_equal 'United States Dollar', usd[2]
      end
      
      should 'get rates for views' do
        res = currency_rates(%w{EUR CHF USD}, 'CHF')
        assert_match /^\[\["EUR", [0-9\.]+, "Euro"\], \["CHF", 1.0, "Swiss Franc"\], \["USD", [0-9\.]+, "United States Dollar"\]\]$/, res
      end
    end
  end
end