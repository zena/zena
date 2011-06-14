require 'test_helper'

class PropEvalTest < Zena::Unit::TestCase

  class NodesRoles < ActiveRecord::Base
    set_table_name :nodes_roles
  end

  def idx_ml_value(obj_id, key, lang=visitor.lang)
    IdxNodesMlString.find(:first,
      :conditions => {:node_id => obj_id, :lang => lang, :key => key}
    ).value
  end

  def idx_value(obj_id, key)
    IdxNodesString.find(:first,
      :conditions => {:node_id => obj_id, :key => key}
    ).value
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
          # TODO: support queries as safe method directly on nodes (also change zena/use/query_builder.rb).
          # subject.update_attributes(:prop_eval => %q[{'title' => "#{paper} #{recipient.name}"}])
          subject.update_attributes(:prop_eval => %q[{'paper' => (paper.blank? ? 'Chiyogami' : paper), 'title' => 'booh'}])
        end
      end # with valid code

      context 'with valid code using vclass methods' do
        subject do
          secure(VirtualClass) { virtual_classes(:Post) }
        end

        should 'succeed' do
          assert subject.update_attributes(:prop_eval => %q[{'date' => (date || now)}])
        end
      end # with valid code

      context 'with syntax errors' do
        should 'fail' do
          assert !subject.update_attributes(:prop_eval => %q[{foo:#{tit}le} paper:#{paper}}])
          assert_match %r{parse error}, subject.errors[:prop_eval]
        end
      end # with syntax errors

      context 'with invalid final type' do
        should 'fail' do
          assert !subject.update_attributes(:prop_eval => %q[45])
          assert_equal 'Compilation should produce a Hash (Found Number).', subject.errors[:prop_eval]
        end
      end # with syntax errors
    end # updating a virtual_class
  end # A visitor with admin rights

  context 'A visitor with write access' do
    setup do
      login(:lion)
      klass = roles(:Contact)
      assert klass.update_attributes(
        :prop_eval => %q{{'title' => "#{id} / #{first_name} #{name}"}}
      )
      deb VirtualClass['Contact'].prop_eval
    end

    context 'creating a node from a class with prop eval' do
      subject do
        secure(Node) { Node.create_node(:class => 'Contact', :name => 'foo', :parent_id => nodes_zip(:projects)) }
      end

      should 'set evaluated prop on create' do
        assert_difference('Node.count', 1) do
          node = subject
          # should have 'zip' during prop_eval
          assert_equal %r{foo\Z}, node.title
        end
      end

      should 'have zip during prop_eval' do
        node = subject
        # should have 'zip' during prop_eval
        assert_equal %r{\A#{node.zip}}, node.title
      end
    end # creating a node from a class with prop eval


    context 'unpublishing a node from a class with prop eval' do
      subject do
        secure(Node) { nodes(:ant) }
      end

      should 'succeed' do
        assert subject.unpublish
      end
    end # unpublishing a node from a class with prop eval

    context 'on a node' do
      setup do
        VirtualClass.expire_cache!
      end

      context 'from a class with evaluated properties' do
        subject do
          secure(Node) { nodes(:ant) }.tap do |n|
            n.update_attributes(:first_name => 'Dan', :name => 'Simmons')
          end
        end

        context 'updating attributes' do
          should 'update evaluated prop on save' do
            assert_equal 'Dan Simmons', subject.title
          end

          should 'use evaluated prop in fulltext indices' do
            assert_equal 'Dan Simmons', subject.version.idx_text_high
          end

          context 'with property indices' do
            subject do
              secure(Node) { nodes(:letter) }.tap do |n|
                assert n.update_attributes(:paper => 'Origami', :v_status => Zena::Status::Pub)
              end
            end

            should 'use evaluated prop in ml prop indices' do
              assert_equal 'zena enhancements paper:Origami', idx_ml_value(subject.id, 'search')
            end

            should 'use evaluated prop in prop indices' do
              assert_equal 'Origami mono', idx_value(subject.id, 'search_mono')
            end
          end # with property indices

        end # updating attributes

        context 'rebuilding index' do
          setup do
            login(:lion)
            vclass = secure(Role) { roles(:Contact) }
            # changed prop_eval
            assert vclass.update_attributes(:prop_eval => %q[{'title' => "LAST:#{name} FIRST:#{first_name}"}])
          end

          subject do
            secure(Node) { nodes(:ant) }
          end

          should 'evaluate prop' do
            subject.rebuild_index!
            assert_equal 'LAST:Invicta FIRST:Solenopsis', idx_ml_value(subject.id, 'title')
            assert_equal 'LAST:Invicta FIRST:Solenopsis', nodes(:ant).title
          end
        end # rebuilding index

      end # from a class with evaluated properties

      context 'from a class with prop eval used as default' do
        setup do
          vclass = secure(Role) { roles(:Contact) }
          assert vclass.update_attributes(:prop_eval => %q[{'title' => (title.blank? ? 'Bikura' : title)}])
        end

        subject do
          secure(Node) { nodes(:ant) }
        end

        should 'not set default if not blank' do
          assert subject.update_attributes(:title => 'Super Man')
          assert_equal 'Super Man', subject.title
        end

        should 'set default if blank' do
          assert subject.update_attributes(:title => '')
          assert_equal 'Bikura', subject.title
        end
      end # from a class with prop eval used as default

      context 'from a class with query in prop eval' do
        setup do
          vclass = secure(Role) { roles(:Contact) }
          assert vclass.update_attributes(:prop_eval => %q[{'title' => first('project in site').title}])
        end

        subject do
          secure(Node) { nodes(:ant) }
        end

        should 'execute query to set property' do
          assert subject.update_attributes(:title => '')
          assert_equal 'Zena the wild CMS', subject.title
        end
      end # from a class with prop eval used as default

      context 'from a native class' do
        subject do
          secure(Node) { nodes(:projects) }
        end

        should 'not raise on save' do
          assert_nothing_raised do
            assert subject.update_attributes(:title => 'Hyperion')
          end
          assert_equal 'Hyperion', subject.title
        end

        should 'rebuild prop_eval on klass change' do
          assert subject.update_attributes(:klass => 'Letter')
          node = secure(Node) { Node.find(subject.id)}
          assert_equal 'projects list paper:', node.search
        end
      end # from a native class

    end # on a node
  end # A visitor with write access

  context 'The VirtualClass class' do
    subject do
      VirtualClass
    end

    should 'contain prop_eval in export attributes' do
      assert subject.export_attributes.include?('prop_eval')
    end
  end # A VirtualClass
end
