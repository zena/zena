require 'test_helper'

class MLIndexTest < Zena::Unit::TestCase
  context 'A visitor with write access' do
    setup do
      login(:lion)
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
        setup do
          buz = VirtualClass.create(:superclass => 'Node', :name => 'Buz', :create_group_id => groups_id(:public))
          assert !buz.new_record?
          col = Column.create(:role_id => buz.id, :ptype => 'string', :name => 'foo', :index => 'string')
          assert !col.new_record?
        end
        
        teardown do
          # avoid test leakage
          VirtualClass.expire_cache!
        end
        
        subject do
          secure(Node) { Node.create_node(
            :class     => 'Buz',
            :title     => 'Zanzibar',
            :foo       => 'bar',
            :parent_id => nodes_zip(:cleanWater)
          )}
        end

        should 'insert single value' do
          assert_difference('IdxNodesString.count', 1) do
            # title = 4, foo = 1
            assert !subject.new_record?
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

      should 'rebuild index for current lang' do
        assert_difference('IdxNodesMlString.count', 0) do
          subject.update_attributes(:title => 'fabula', :v_status => Zena::Status[:pub])
        end
        idx = IdxNodesMlString.find(:first,
          :conditions => {:node_id => subject.id, :lang => visitor.lang, :key => 'title'}
        )
        assert_equal 'fabula', idx.value
      end

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

      context 'in a class with evaluated properties' do
        subject do
          secure(Node) { nodes(:ant) }
        end

        should 'index commputed value' do
          assert subject.update_attributes(:first_name => 'Superman')
          assert_equal 'Superman Invicta', subject.title
          idx = IdxNodesMlString.find(:first, :conditions => ["lang = ? AND `key` = ? AND node_id = ?", visitor.lang, 'title', subject.id])
          assert_equal 'Superman Invicta', idx.value
        end

        context 'with changes overwritten by computed values' do
          should 'not touch index' do
            assert_difference('IdxNodesMlString.count', 0) do
              subject.update_attributes(:title => 'fabula', :v_status => Zena::Status[:pub])
            end
            idx = IdxNodesMlString.find(:first,
              :conditions => {:node_id => subject.id, :lang => visitor.lang, :key => 'title'}
            )

            assert_equal 'Solenopsis Invicta', idx.value
          end
        end # with changes overwritten by computed values

      end # in a class with evaluated properties

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

        context 'with prop_eval defined for vclass' do
          subject do
            secure(Node) { nodes(:letter) }
          end

          should 'set index from computed value' do
            subject.rebuild_index!
            ml_indices = Hash[*IdxNodesMlString.find(:all, :conditions => {:node_id => subject.id, :key => 'search'}).map {|r| [r.lang, r.value]}.flatten]
            assert_equal Hash[
              'fr'=>'zena enhancements paper:Kraft',
              'de'=>'zena enhancements paper:Kraft',
              'es'=>'zena enhancements paper:Kraft',
              'en'=>'zena enhancements paper:Kraft'], ml_indices
          end
        end # with idx_text_high defined for vclass

      end # without indices in table

    end # on a node

  end # A visitor with write access
end
