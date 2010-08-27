# encoding: utf-8
require 'test_helper'

class SerializableTest < Zena::Unit::TestCase

  def self.should_not_change_object_on_rewrite
    should 'not alter object on update with to_xml content' do
      hash = Hash.from_xml(subject.to_xml)['node']
      subject = secure(Node) { Node.find_by_zip(hash.delete('id'))}
      subject.attributes = Node.transform_attributes(hash)
      assert !subject.changed?
    end
  end # self.should_not_change_object_on_rewrite

  context 'A visitor with write access' do
    setup do
      login(:tiger)
    end

    context 'on a node' do
      subject do
        secure(Node) { nodes(:status) }
      end

      context 'with non-ascii characters' do
        setup do
          subject.update_attributes('title' => "à l'école")
        end

        should_not_change_object_on_rewrite

        should 'encode xml in utf-8' do
          assert_match %r{encoding=.UTF-8.*&#224; l'&#233;cole}m, subject.to_xml
        end
      end

      context 'with empty properties' do
        # origin is empty
        should 'remove blank values from xml' do
          assert_no_match %r{<origin}, subject.to_xml
        end
      end

      context 'with many tags for one role' do
        subject do
          secure(Node) { nodes(:art) }
        end

        should_not_change_object_on_rewrite

        should 'join link_id values with comma' do
          hash = Hash.from_xml(subject.to_xml)['node']
          assert_match %r{27,21|21,27}, hash['tagged_ids']
        end

        should 'have zero link' do

          sql = %Q{SELECT id, source_id, target_id FROM links WHERE id = 0}

          assert_not_nil Zena::Db.select_all(sql).first
        end

        should 'parse link ids to zips on all_link_ids' do
          assert_equal Hash['parent_id'=>'32', 'tagged_ids'=>["27", "21"]], subject.all_link_ids
        end
      end

      context 'with legacy properties' do
        subject do
          # 'cleanWater' contains old properties that do not correspond to any role (tz for example).
          secure(Node) { nodes(:cleanWater) }
        end

        should_not_change_object_on_rewrite

        should 'ignore legacy properties in xml' do
          hash = Hash.from_xml(subject.to_xml)['node']
          assert_not_nil subject.prop['tz']
          assert_nil hash['tz']
        end
      end

    end # on a node

    context 'on many nodes' do
      subject do
        xml = secure(Node) { Node.search_records(:qb => 'images in site') }.to_xml(:root => 'nodes')
        Hash.from_xml(xml)
      end

      should 'use nodes as root' do
        assert subject['nodes']
        assert_equal 4, subject['nodes'].size
      end
    end # on many nodes
  end # A visitor with read access
end
