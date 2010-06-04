require 'test_helper'

class EnrollableTest < Zena::Unit::TestCase
  context 'A visitor with write access' do
    setup do
      login(:tiger)
    end

    context 'creating a node' do
      # Node has 'title' as multilingual index
      subject do
        secure(Node) { Node.create(
          :title     => 'Piksel',
          :parent_id => nodes_id(:cleanWater)
        )}
      end

      should 'write index for every language available' do
        assert_difference('IdxNodesMlString.count', 4) do
          subject
        end
      end

      context 'with non ML indices' do
        subject do
          k = Class.new(Node) do
            property.string 'foo', :index => true
          end
          secure(k) { k.create(
            :title     => 'Zanzibar',
            :foo       => 'bar',
            :parent_id => nodes_id(:cleanWater)
          )}
        end

        should 'insert single value' do
          assert_difference('IdxNodesString.count', 1) do
            # title = 4, name = 1
            assert subject
          end
        end
      end # with non ML indices

    end # creating a node

    context 'updating a node' do
      setup do
        visitor.lang = 'fr'
      end

      subject do
        secure(Node) { nodes(:news) }
      end

      context 'with std indices removed' do
        setup do
          IdxNodesString.connection.execute 'DELETE from idx_nodes_strings'
        end

        should 'not write std index on skip_std_index' do
          subject = secure(Node) { nodes(:ant) }
          subject.instance_variable_set(:@skip_std_index, true)
          assert_difference('IdxNodesString.count', 0) do
            subject.update_attributes(:name => 'New')
          end
        end
      end # with std indices removed

      context 'with multi lingual indices removed' do
        setup do
          IdxNodesMlString.connection.execute 'DELETE from idx_nodes_ml_strings'
        end

        should 'write index for concerned language only' do
          assert_difference('IdxNodesMlString.count', 1) do
            subject.update_attributes('title' => 'Nouvelles')
          end
        end
      end # with multi lingual indices removed
    end # updating a node

    context 'on a node' do
      subject do
        secure(Node) { nodes(:status) }
      end

      context 'without indices in table' do
        setup do
          IdxNodesMlString.connection.execute "DELETE from idx_nodes_ml_strings"
        end

        should 'rebuild index for all langs' do
          assert_difference('IdxNodesMlString.count', 4) do
            subject.rebuild_index!
          end
        end

        should 'set proper content for each lang' do
          subject.rebuild_index!
          ml_indices = Hash[*IdxNodesMlString.find(:all, :conditions => {:node_id => nodes_id(:status), :key => 'title'}).map {|r| [r.lang, r.value]}.flatten]
          assert_equal Hash[
            'de'=>'status title',
            'fr'=>'Etat des travaux',
            'es'=>'status title',
            'en'=>'status title'], ml_indices
        end

        context 'with idx_text_high defined for vclass' do
          subject do
            secure(Node) { nodes(:letter) }
          end

          should 'set title index from idx_text_high' do
            subject.rebuild_index!
            ml_indices = Hash[*IdxNodesMlString.find(:all, :conditions => {:node_id => subject.id, :key => 'title'}).map {|r| [r.lang, r.value]}.flatten]
            assert_equal Hash[
              'de'=>'zena enhancements paper:Kraft',
              'fr'=>'zena enhancements paper:Kraft',
              'es'=>'zena enhancements paper:Kraft',
              'en'=>'zena enhancements paper:Kraft'], ml_indices
          end
        end # with idx_text_high defined for vclass

      end # without indices in table

    end # on a node

  end # A visitor with write access
end
