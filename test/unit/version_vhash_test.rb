require 'test_helper'

class VersionVhashTest < Zena::Unit::TestCase
  class Simple < ActiveRecord::Base
    set_table_name 'nodes'
    include Zena::Use::MultiVersion
    include Zena::Use::VersionHash

    def can_see_redactions?
      true
    end

    def current_transition
      {:name => Thread.current[:vhash_transition_name]}
    end
  end

  context 'Creating a new object' do
    setup do
      visitor.lang = 'fx'
      transition_mock :edit
    end

    should 'set vhash after create' do
      simple = Simple.create('user_id' => visitor.id, 'version_attributes' => {'title' => "foo"})
      assert_equal Hash['w'=>{'fx'=>simple.version.id}, 'r'=>{}], simple.vhash
    end
  end

  private
    def transition_mock(name)
      Thread.current[:vhash_transition_name] = name
    end

end
