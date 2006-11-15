require "#{File.dirname(__FILE__)}/../test_helper"

class CachingTest < ActionController::IntegrationTest

  self.use_transactional_fixtures = true
  self.use_instantiated_fixtures  = false

  # Replace this with your real tests.
  def test_render_and_cache
    
    # http://blog.cosinux.org/articles/2006/10/05/testing-ruby-on-rails-page-caching
    # test cache if document public but not ZENA_ENV[:autorize] !!
    # test cache if visitor public but not ZENA_ENV[:autorize] !! (???)
    puts 'todo'
  end
end
