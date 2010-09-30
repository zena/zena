require 'test_helper'

class VersionHashTest < Zena::Unit::TestCase

  context 'Creating a Node' do
    setup do
      login(:tiger)
      visitor.lang = 'de'
    end

    subject do
      secure!(Page) { Page.create('parent_id' => nodes_id(:cleanWater), 'title' => 'Bloom filter') }
    end

    should 'set a writers entry for the current lang' do
      assert_equal Hash['w'=>{'de'=>subject.version.id}, 'r'=>{}], subject.vhash
    end

    should 'copy writers entry to readers on publish' do
      subject.publish
      assert_equal Hash['w'=>{'de'=>subject.version.id}, 'r'=>{'de'=>subject.version.id}], subject.vhash
    end

    context 'with auto publish' do

      subject do
        secure!(Page) { Page.create(
          :parent_id => nodes_id(:cleanWater),
          :v_status  => Zena::Status[:pub],
          :title     => 'Bloom filter')
        }
      end

      should 'set a readers and writers entry for the current lang' do
        assert_equal Hash['w'=>{'de'=>subject.version.id}, 'r'=>{'de'=>subject.version.id}], subject.vhash
      end
    end # with auto publish
  end # Creating a Node

  context 'Updating a Node' do
    setup do
      login(:tiger)
      visitor.lang = 'de'
      @attributes = {'name' => 'Tigris'}
    end

    subject do
      secure!(Page) { nodes(:tiger) }.tap do |node|
        node.update_attributes(@attributes)
      end
    end

    should 'set a writers entry for the current lang' do
      assert_equal subject.version.id, subject.vhash['w']['de']
    end

    should 'not alter reader entry' do
      assert_nil subject.vhash['r']['de']
    end

    should 'copy writers entry to readers on publish' do
      subject.publish
      assert_equal subject.version.id, subject.vhash['w']['de']
      assert_equal subject.version.id, subject.vhash['r']['de']
    end

    context 'with auto publish' do
      setup do
        @attributes = {'name' => 'Tigris Tigris', :v_status => Zena::Status[:pub]}
      end

      should 'set a readers and writers entry for the current lang' do
        assert_equal subject.version.id, subject.vhash['w']['de']
        assert_equal subject.version.id, subject.vhash['r']['de']
      end
    end # with auto publish
    
    context 'with remove status' do
      setup do
        @attributes = {:v_status => Zena::Status[:rem]}
      end

      should 'remove readers entry' do
        assert_nil subject.vhash['r']['en']
      end
      
      should 'keep writers entry' do
        assert_equal versions_id(:tiger_en), subject.vhash['w']['en']
      end
    end # with remove status
  end # Updating a Node
  
  context 'On a node' do
    setup do
      login(:ant)
    end
    
    context 'with published and not published versions' do
      subject do
        secure(Node) { nodes(:opening)}
      end

      should 'return all versions in vhash on visible_versions' do
        list = subject.visible_versions
        assert_equal [:opening_fr, :opening_en, :opening_red_fr].map {|v| versions_id(v)}.sort, list.map(&:id).sort
      end
    end # with published and not published versions
    
    context 'with published versions' do
      subject do
        login(:tiger)
        visitor.lang = 'fr'
        n = secure(Node) { nodes(:opening)}
        n.publish
        secure(Node) { nodes(:opening)}
      end

      should 'not return removed versions on visible_versions' do
        list = subject.visible_versions
        assert_equal [:opening_en, :opening_red_fr].map {|v| versions_id(v)}.sort, list.map(&:id).sort
      end
    end # with published and not published versions
    
  end # on a node
  
end
