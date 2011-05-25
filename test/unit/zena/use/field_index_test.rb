require 'test_helper'

class FieldIndexTest < Zena::Unit::TestCase
  context 'A visitor with write access' do
    setup do
      login(:lion)
    end

    context 'creating a node' do

      context 'that is not published' do
        # Post has 'date' as field index
        subject do
          secure(Node) { Node.create_node(
            :title     => 'Piksel',
            :parent_id => nodes_zip(:cleanWater),
            :class     => 'Post',
            :date      => '2011-05-25'
          )}
        end

        should 'write index in field' do
          assert_equal '2011-05-25', subject.idx_datetime1.strftime('%Y-%m-%d')
        end
      end # that is not published
    end # creating a node
  end # A visitor with write access
end
