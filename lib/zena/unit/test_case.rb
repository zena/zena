module Zena
  module Unit
    class TestCase < ActiveSupport::TestCase
      include Zena::Use::Fixtures
      include Zena::Use::TestHelper
      include Zena::Acts::Secure

      def setup
        $_test_site = 'zena'
        login(:anon)
      end

      # Set visitor for unit testing
      def login(name='anon',site_name = nil)
        # set site (find first matching site)
        site = Site.find(:first, :select=>"sites.*, sites.name = '#{site_name}' AS site_ok", :from => "sites, participations",
                         :conditions=>["participations.site_id = sites.id AND participations.user_id = ?", users_id(name)], :order => "site_ok DESC")

        $_test_site  = site.name if site
        visitor = User.make_visitor(:site => site, :id => users_id(name))
        visitor.ip = '10.0.0.127'
        # FIXME: I18n: set visitor.lang
      end

      def err(obj)
        obj.errors.each do |er,msg|
          puts "[#{er}] #{msg}"
        end
      end

    end
  end
end