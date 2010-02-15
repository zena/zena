require 'test/test_helper'
require "authlogic/test_case"
require 'hpricot'

include Zena::Acts::Secure

module Console

  include Zena::Use::Fixtures
  include Zena::Use::TestHelper
  include Zena::Acts::Secure
  include ::Authlogic::TestCase


  def controller
    @controller ||= Authlogic::TestCase::MockController.new
  end

  def setup_authlogic
    Authlogic::Session::Base.controller = (@request && Authlogic::TestCase::RailsRequestAdapter.new(@request)) || controller
  end


  def visitor
    Thread.current[:visitor]
  end

  module_function :controller, :activate_authlogic, :login, :users, :versions, :visitor

end

Console.activate_authlogic

