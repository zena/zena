require 'test_helper'

class FulltextTest < Zena::Unit::TestCase

  class NodesRoles < ActiveRecord::Base
    set_table_name :nodes_roles
  end

  context 'A visitor with admin rights' do
    setup do
      login(:lion)
    end

    context 'updating a virtual_class' do
      subject do
        secure(VirtualClass) { virtual_classes(:Letter) }
      end

      context 'with valid code' do
        should 'succeed' do
          assert subject.update_attributes(:idx_text_high => %q{sender:#{title} paper:#{paper}})
        end
      end # with valid code

      context 'with syntax errors' do
        should 'fail' do
          assert !subject.update_attributes(:idx_text_high => %q[foo:#{tit}le} paper:#{paper}])
          assert_match %r{parse error}, subject.errors[:idx_text_high]
        end
      end # with syntax errors

    end # updating a virtual_class
  end # A visitor with admin rights

  context 'A visitor with write access' do
    setup do
      login(:tiger)
    end

    context 'on a node' do
      context 'from a class with fulltext indices' do
        subject do
          secure(Node) { nodes(:letter) }
        end

        should 'update index on save' do
          subject.update_attributes(:paper => 'Green')
          assert_equal 'title:zena enhancements paper:Green', subject.version.idx_text_high
        end
      end # from a class with fulltext indices

      context 'from a class without fulltext indices' do
        subject do
          secure(Node) { nodes(:art) }
        end

        should 'update default index on save' do
          subject.update_attributes(:title => 'Spiral Jetty')
          assert_equal 'Spiral Jetty', subject.version.idx_text_high
        end
      end # from a class with fulltext indices
    end # on a node
  end # A visitor with write access
end
