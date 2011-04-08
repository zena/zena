module Zena
  module Unit
    class TestCase < ActiveSupport::TestCase
      include Zena::Use::Fixtures
      include Zena::Use::TestHelper
      include Zena::Acts::Secure
      include ::Authlogic::TestCase

      setup :activate_authlogic

      def setup
        #log anonymously by default
        login(:anon)
      end

      def self.helper_attr(*args)
        # Ignore since we include helpers in the TestCase itself
      end

      # Specific helpers to validate model relations and queries with SQLiss
      def main_date
        raise "The test uses 'validate_query' without defining @main_date" unless @main_date
        return @main_date.strftime("'%Y-%m-%d'")
      end

      # Test a query (useful with complex custom queries). Usage:
      #
      #    validate_query "emp_comp_dates where log_at is not null", [
      #      { :title    => 'Creativity',
      #        :priority => '5',
      #        :log_at   => '2010-06-01',
      #        :event_at => '2011-06-01',
      #      },
      #      { :title    => 'Leadership',
      #        :priority => '5',
      #        :log_at   => '2003-01-01',
      #        :event_at => nil, # forever
      #      },
      #    ]
      #
      def validate_query(query, expected_list)
        list = subject.find(:all, query.gsub('&lt;', '<').gsub('&gt;', '>'), :errors => true)
        if expected_list.nil? || expected_list.empty?
          assert_equal nil, list
        elsif expected_list.first.kind_of?(String)
          assert_equal expected_list, list.map(&:title)
        elsif list.nil?
          assert_equal expected_list, list
        elsif list.kind_of?(::QueryBuilder::Error)
          assert_equal expected_list, list.to_s
        else
          proto = expected_list.first.keys
          sz = [expected_list.size, list.size].max

          (0..(sz-1)).to_a.each do |i|
            record   = list[i]
            expected = expected_list[i]
            if not record
              assert_equal expected[:title], nil
            elsif not expected
              assert_equal nil, map_to_proto(proto, record)
            else
              if expected[:title] != record.title
                assert_equal expected[:title], map_to_proto(proto, record)
              else
                expected.keys.each do |key|
                  value = format_date(record[key] || record.send(key))
                  assert_equal expected[key], value, "(#{record.title} #{key} expected to be #{expected[key].inspect} but was #{value.inspect}"
                end
              end
            end
          end
        end
      end

      private
        def format_date(date)
          if date.respond_to?(:strftime)
            date.strftime('%Y-%m-%d')
          else
            date
          end
        end

        def map_to_proto(proto, record)
          Hash[*proto.map{|k| [k, format_date(record[k] || record.send(k))]}.flatten]
        end
    end
  end
end