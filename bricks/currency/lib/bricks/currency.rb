require 'uri'
require 'net/http'

# To use this gem, simply enable the currency gem and set app_id from openexchangerates.org
#   currency:
#     switch: ON
#     app_id: the_secret_app_id
#
# You can then get
module Bricks
  module Currency
    # We have a module accessor so that we can rewrite app_id during testing
    mattr_accessor :app_id
    
    self.app_id = Bricks::CONFIG['currency']['app_id']
    
    EXCHANGE_URI = "http://openexchangerates.org/api/latest.json"
    CURRENCY_URI = "http://openexchangerates.org/api/currencies.json"
    
    @@exchange_rates = {
      :expire_at  => Time.now.utc.advance(:year => -1),
      :rates      => {},
      :currencies => nil,
    }
    
    # Returns a list of rates from the base rate to currency keys in the list with currency full name:
    # ==> [['USD', 1.23, 'US Dollar'], ['EUR', 1.0, 'Euro'], ...]
    def self.get_rates(list, base = 'USD')
      stamp = Time.now.utc
      rates = {}
      if @@exchange_rates[:expire_at] <= stamp
        # Reload exchange rates
        
        app_id = self.app_id
        raise "Missing 'currency/app_id' in config/bricks.yml" if app_id.blank?
        exchange_uri = URI.parse("#{EXCHANGE_URI}?app_id=#{app_id}")
        Net::HTTP.new(exchange_uri.host, exchange_uri.port).start do |http|
          response = http.request_get(exchange_uri.request_uri)
          if response.kind_of?(Net::HTTPSuccess)
            rates = JSON.parse(response.body)['rates']
          else
            raise "Could not get exchange rates (#{response.body})."
          end
        end
        @@exchange_rates[:rates] = rates
        @@exchange_rates[:expire_at] = stamp.advance(:hour => 6) # Update currency rate every 6 hours (works with the free plan)
      else
        rates = @@exchange_rates[:rates]
      end

      curr = self.get_currencies
      # Base for rates = USD
      if base != 'USD'
        ratio = rates[base]
        raise "Invalid base currency '#{base}'" if ratio.nil?
      end
      list.map do |l|
        rate  = rates[l]
        title = curr[l]
        if !rate
          rate = 0.0
          title = "#{title} (Error: could not get exchange rate)"
        elsif ratio
          rate = rate / ratio
        end
        [l, rate, title]
      end
    end

    def self.get_currencies
      @@exchange_rates[:currencies] ||= begin
        app_id = self.app_id
        raise "Missing 'currency/app_id' in config/bricks.yml" if app_id.blank?
        currency_uri = URI.parse("#{CURRENCY_URI}?app_id=#{app_id}")
        Net::HTTP.new(currency_uri.host, currency_uri.port).start do |http|
          response = http.request_get(currency_uri.request_uri)
          if response.kind_of?(Net::HTTPSuccess)
            JSON.parse(response.body)
          else
            raise "Could not get currencies (#{response.body})."
          end
        end
      end
    end
    
    module ZafuMethods
      # Used to build a currency selector with current exchange rates from openexchangerates API.
      def r_currency_options
        return parser_error('missing list parameter') unless list = @params[:list]
        list = ::RubyLess.translate(self, list)
        base = ::RubyLess.translate(self, @params[:selected] || 'nil')
        out "<%= currency_options(#{list}, #{base}) %>"
      end
    end
    
    module ViewMethods
      include RubyLess
      
      # Returns jsonp
      safe_method [:currency_rates, [String], String] => String
      
      # Returns a list of currency rates compatible with Javascript.
      def currency_rates(list, base)
        Bricks::Currency.get_rates(list, base).inspect
      rescue
        '[]'
      end
      
      def currency_options(list, base = 'USD')
        Bricks::Currency.get_rates(list, base).map do |n, c, title|
          "<option data-c='#{c}' value='#{n}'#{n==base ? " selected='selected'" : ""}>#{n} (#{title})</option>"
        end.join("\n")
      rescue => err
        Rails.logger.warn "Could not get exchange rates! (#{err.message})"
        "<!-- Could not get exchange rates -->"
      end
    end
  end # Currency
end # Bricks