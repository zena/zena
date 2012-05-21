require 'test_helper'

module NCFoo
end

class NCPage < ActiveRecord::Base
  include RubyLess
  safe_context :root => Page
end

class SubPage < NCPage
  include NCFoo
end

class SubSubPage < SubPage
end

class NCComment
end

class NodeContextTest < Test::Unit::TestCase

  NodeContext = Zafu::NodeContext

  context 'In a blank context' do
    subject do
      NodeContext.new('@node', NCPage)
    end

    should 'return the current name' do
      assert_equal '@node', subject.name
    end

    should 'return the current class' do
      assert_equal NCPage, subject.klass
    end

    should 'return true on will_be with the same class' do
      assert subject.will_be?(NCPage)
    end

    should 'return false on will_be with a sub class' do
      assert !subject.will_be?(SubPage)
    end

    should 'return false on will_be with a different class' do
      assert !subject.will_be?(String)
    end

    should 'return self on a get for the same class' do
      assert_equal subject.object_id, subject.get(NCPage).object_id
    end

    should 'return nil on a get for another class' do
      assert_nil subject.get(NCComment)
    end

    context 'calling as_main' do
      should 'build the name from the class' do
        assert_equal '@nc_page', subject.as_main.name
      end

      should 'return same class' do
        assert_equal subject.klass, subject.as_main.klass
      end
    end

    context 'calling form_name' do
      should 'return underscore name of base class' do
        assert_equal 'nc_page', subject.form_name
      end
    end

    context 'with a sub-class' do
      subject do
        NodeContext.new('@node', SubPage)
      end

      should 'return true on will_be with the same class' do
        assert subject.will_be?(SubPage)
      end

      should 'return true on will_be with a super class' do
        assert subject.will_be?(NCPage)
      end

      should 'return false on will_be with a different class' do
        assert !subject.will_be?(String)
      end

      context 'calling form_name' do
        should 'return underscore name of base class' do
          assert_equal 'nc_page', subject.form_name
        end
      end

      context 'calling as_main' do
        should 'build the name from the class' do
          assert_equal '@sub_page', subject.as_main.name
        end

        should 'return same class' do
          assert_equal subject.klass, subject.as_main.klass
        end

        should 'return current class when using after_class argument' do
          subject = NodeContext.new('@node', SubSubPage)
          assert_equal SubSubPage, subject.as_main(NCPage).klass
        end

        should 'rebuild name from ancestor when using after_class argument' do
          subject = NodeContext.new('@node', SubSubPage)
          assert_equal '@sub_page', subject.as_main(NCPage).name
        end

        context 'in a list context' do
          subject do
            NodeContext.new('list', [SubSubPage])
          end

          should 'return current class when using after_class argument' do
            assert_equal SubSubPage, subject.as_main(NCPage).klass
          end

          should 'rebuild name from ancestor when using after_class argument' do
            assert_equal '@sub_page', subject.as_main(NCPage).name
          end
        end # in a list context

      end

      should 'return subclass on class_name' do
        assert_equal 'SubPage', subject.class_name
      end
    end # with a sub-class

    context 'with an anonymous sub-class' do
      subject do
        NodeContext.new('@node', Class.new(NCPage))
      end

      should 'return class on class_name' do
        assert_equal 'NCPage', subject.class_name
      end
    end # with an anonymous sub-class
  end

  context 'In a sub-context' do
    setup do
      @parent  = NodeContext.new('@node', NCPage)
    end

    subject do
      @parent.move_to('comment1', NCComment)
    end

    should 'return the current name' do
      assert_equal 'comment1', subject.name
    end

    should 'return the current class' do
      assert_equal NCComment, subject.klass
    end

    should 'return self on a get for the same class' do
      assert_equal subject.object_id, subject.get(NCComment).object_id
    end

    should 'return the parent on a get for the class of the parent' do
      assert_equal @parent.object_id, subject.get(NCPage).object_id
    end
  end

  context 'In a deeply nested context' do
    setup do
      @grandgrandma = NodeContext.new('@comment', NCComment)
      @grandma = @grandgrandma.move_to('page', NCPage)
      @mother  = @grandma.move_to('comment1', NCComment)
    end

    subject do
      @mother.move_to('var1', String)
    end

    should 'return the current name' do
      assert_equal 'var1', subject.name
    end

    should 'return the current class' do
      assert_equal String, subject.klass
    end

    should 'return the first ancestor matching class on get' do
      assert_equal @mother.object_id, subject.get(NCComment).object_id
    end

    should 'return nil if no ancestor matches class on get' do
      assert_nil subject.get(Fixnum)
    end

    should 'return the parent on up' do
      assert_equal @mother, subject.up
    end
  end

  context 'In a sub-classes context' do
    subject do
      NodeContext.new('super', SubPage)
    end

    should 'find the required class in ancestors' do
      assert_equal subject.object_id, subject.get(NCPage).object_id
    end
  end

  context 'In a list context' do
    setup do
      @grandma = NodeContext.new('@nc_page', SubPage)
      @mother = @grandma.move_to('@comment', NCComment)
    end

    subject do
      @mother.move_to('list', [NCPage])
    end

    should 'find the context and resolve without using first' do
      assert context = subject.get(NCPage)
      assert_equal '@nc_page', context.name
      assert_equal SubPage, context.klass
    end

    should 'return parent on up with class' do
      assert_equal @grandma, subject.up(NCPage)
    end

    should 'return true on will_be with the same class' do
      assert subject.will_be?(NCPage)
    end

    should 'return class on master_class' do
      assert_equal NCPage, subject.master_class(ActiveRecord::Base)
    end
  end

  context 'In a deeply nested list context' do
    setup do
      @grandma = NodeContext.new('@nc_page', SubPage)
      @mother = @grandma.move_to('@comment', NCComment)
    end

    subject do
      @mother.move_to('list', [[[NCPage]]])
    end

    should 'find the context without using first' do
      assert context = subject.get(NCPage)
      assert_equal '@nc_page', context.name
      assert_equal SubPage, context.klass
    end

    should 'return parent on up with class' do
      assert_equal @grandma, subject.up(NCPage)
    end

    should 'return true on will_be with the same class' do
      assert subject.will_be?(NCPage)
    end

    should 'return class on master_class' do
      assert_equal NCPage, subject.master_class(ActiveRecord::Base)
    end
  end

  context 'Generating a dom id' do
    context 'in a blank context' do
      subject do
        n = NodeContext.new('@foo', NCPage)
        n.dom_prefix = 'list1'
        n
      end

      should 'return the node name in DOM id' do
        assert_equal '<%= %Q{list1_#{@foo.zip}} %>', subject.dom_id
      end

      should 'not use zip on list false' do
        assert_equal 'list1', subject.dom_id(:list => false)
      end

      should 'scope without erb on erb false' do
        assert_equal 'list1_#{@foo.zip}', subject.dom_id(:erb => false)
      end
    end

    context 'in a hierarchy of contexts' do
      setup do
        @a       = NodeContext.new('@node', NCPage)
        @a.dom_prefix = 'a'
        @b       = NodeContext.new('var1', [NCPage], @a)
        @b.dom_prefix = 'b'
        @c       = NodeContext.new('var2', NCPage, @b)
      end

      subject do
        NodeContext.new('var3', NCPage, @c)
      end

      context 'with parents as dom_scopes' do
        setup do
          @b.propagate_dom_scope!
          @c.propagate_dom_scope!
        end

        should 'use dom_scopes' do
          assert_equal '<%= %Q{b_#{var1.zip}_#{var2.zip}_#{var3.zip}} %>', subject.dom_id
        end

        should 'use dom_scopes and dom_prefix not in list' do
          subject.dom_prefix = 'd'
          assert_equal '<%= %Q{b_#{var1.zip}_#{var2.zip}_d} %>', subject.dom_id(:list => false)
        end
        
        context 'with a saved dom_id' do
          setup do
            @c.saved_dom_id = '#{ndom_id(@foo)}'
          end
          
          should 'use saved id in scope' do
            assert_equal '<%= %Q{#{ndom_id(@foo)}_#{var3.zip}} %>', subject.dom_id
          end
        end
      end
      
      context 'with a saved dom_id' do
        setup do
          @c.saved_dom_id = '#{ndom_id(@foo)}'
        end
        
        should 'not use saved id in scope' do
          # We did not ask for dom_scope to propagate.
          assert_equal '<%= %Q{b_#{var3.zip}} %>', subject.dom_id
        end
      end

      context 'with ancestors and self as dom_scopes' do
        setup do
          @a.propagate_dom_scope!
          subject.propagate_dom_scope!
        end

        should 'not use self twice' do
          assert_equal '<%= %Q{a_#{@node.zip}_#{var3.zip}} %>', subject.dom_id
        end
      end

      context 'with a parent defining a dom_prefix' do
        setup do
          @b.dom_prefix = 'cart'
        end

        should 'use dom_prefix' do
          subject.dom_prefix = nil
          assert_equal '<%= %Q{cart_#{var3.zip}} %>', subject.dom_id
        end
      end

    end
  end
end






