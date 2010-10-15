module Zena
  module Controller
    class TestCase < ActionController::TestCase
      include Zena::Use::Fixtures
      include Zena::Use::TestHelper
      include Zena::Acts::Secure
      include ::Authlogic::TestCase

      def setup
        activate_authlogic
      end

      def login(fixture)
        super
        if defined?(@controller)
          @controller.class_eval do
            def set_visitor
              # do nothing
            end
          end
        end
      end

      %w{get post put delete}.each do |method|
        class_eval <<-END_TXT
          def #{method}_subject
            without_files('/test.host/zafu') do
              #{method} subject.delete(:action), subject
              if block_given?
                yield
              end
            end
          end
        END_TXT
      end

      def assert_match(match, target)
        return super if match.kind_of?(Regexp)
        target = Hpricot(target)
        assert !target.search(match).empty?,
          "expected tag, but no tag found matching #{match.inspect} in:\n#{target.inspect}"
      end

      def assert_no_match(match, target)
        return super if match.kind_of?(Regexp)
        target = Hpricot(target)
        assert target.search(match).empty?,
          "expected not tag, but tag found matching #{match.inspect} in:\n#{target.inspect}"
      end

    end
  end
end