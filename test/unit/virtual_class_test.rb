# encoding: utf-8
require 'test_helper'

class VirtualClassTest < Zena::Unit::TestCase

  def test_virtual_subclasse
    # add a sub class
    login(:lion)
    vclass = VirtualClass.create(:superclass => 'Post', :name => 'Super', :create_group_id => groups_id(:public))
    assert !vclass.new_record?
    assert_equal "NNPS", vclass.kpath
  end

  def test_node_classes_for_form
    login(:anon)
    # preload models
    [Project, Skin, Note, Image, Template]

    classes_for_form = Node.classes_for_form
    assert classes_for_form.include?(["Node", "Node"])
    assert classes_for_form.include?(["  Page", "Page"])
    assert classes_for_form.include?(["  Note", "Note"])
    assert classes_for_form.include?(["  Reference", "Reference"])
    assert classes_for_form.include?(["    Letter", "Letter"])
  end

  def test_note_classes_for_form
    login(:anon)
    # preload models
    [Project, Skin, Note, Image, Template]

    classes_for_form = Note.classes_for_form
    assert classes_for_form.include?(["Note", "Note"])
    assert classes_for_form.include?(["  Letter", "Letter"])
    assert classes_for_form.include?(["  Post", "Post"])
    classes_for_form.map!{|k,c| c}
    assert !classes_for_form.include?("Node")
    assert !classes_for_form.include?("Page")
    assert !classes_for_form.include?("Reference")
  end

  def test_post_classes_for_form
    # add a sub class
    login(:lion)
    vclass = VirtualClass.create(:superclass => 'Post', :name => 'Super', :create_group_id => groups_id(:public))
    assert !vclass.new_record?

    login(:anon)

    classes_for_form = Node.get_class('Post').classes_for_form
    assert classes_for_form.include?(["Post", "Post"])
    assert classes_for_form.include?(["  Super", "Super"])
    classes_for_form.map!{|k,c| c}
    assert !classes_for_form.include?("Node")
    assert !classes_for_form.include?("Note")
    assert !classes_for_form.include?("Letter")
    assert !classes_for_form.include?("Page")
    assert !classes_for_form.include?("Reference")
  end

  def test_post_classes_for_form_opt
    # add a sub class
    login(:lion)
    vclass = VirtualClass.create(:superclass => 'Post', :name => 'Super', :create_group_id => groups_id(:public))
    assert !vclass.new_record?

    login(:anon)

    classes_for_form = Node.classes_for_form(:class => 'Post')
    assert classes_for_form.include?(["Post", "Post"])
    assert classes_for_form.include?(["  Super", "Super"])
    classes_for_form.map!{|k,c| c}
    assert !classes_for_form.include?("Node")
    assert !classes_for_form.include?("Note")
    assert !classes_for_form.include?("Letter")
    assert !classes_for_form.include?("Page")
    assert !classes_for_form.include?("Reference")
  end

  def test_post_classes_for_form_opt
    # add a sub class
    login(:lion)
    vclass = VirtualClass.create(:superclass => 'Post', :name => 'Super', :create_group_id => groups_id(:public))
    assert !vclass.new_record?

    login(:anon)

    classes_for_form = Node.classes_for_form(:class => 'Post', :without=>'Super')
    assert classes_for_form.include?(["Post", "Post"])
    classes_for_form.map!{|k,c| c}
    assert !classes_for_form.include?("Node")
    assert !classes_for_form.include?("Note")
    assert !classes_for_form.include?("Letter")
    assert !classes_for_form.include?("Page")
    assert !classes_for_form.include?("Reference")
    assert !classes_for_form.include?("Super")
  end

  def test_node_classes_for_form_except
    login(:anon)
    # preload models
    [Project, Skin, Note, Image, Template]

    classes_for_form = Node.classes_for_form(:without => 'Letter')
    assert classes_for_form.include?(["Node", "Node"])
    assert classes_for_form.include?(["  Page", "Page"])
    assert classes_for_form.include?(["  Note", "Note"])
    assert classes_for_form.include?(["  Reference", "Reference"])
    classes_for_form.map!{|k,c| c}
    assert !classes_for_form.include?("Letter")

    classes_for_form = Node.classes_for_form(:without => 'Letter,Reference,Truc')
    assert classes_for_form.include?(["Node", "Node"])
    assert classes_for_form.include?(["  Page", "Page"])
    assert classes_for_form.include?(["  Note", "Note"])
    classes_for_form.map!{|k,c| c}
    assert !classes_for_form.include?("Letter")
    assert !classes_for_form.include?("Reference")
  end

  def test_node_classes_read_group
    login(:anon)
    classes_for_form = Node.classes_for_form
    assert !classes_for_form.include?(["    Tracker", "Tracker"])
    login(:lion)
    classes_for_form = Node.classes_for_form
    assert classes_for_form.include?(["    Tracker", "Tracker"])
  end

  def test_vkind_of
    letter = secure!(Node) { nodes(:letter) }
    assert letter.vkind_of?('Letter')
    assert letter.vkind_of?('Note')
    assert letter.kpath_match?('NN')
    assert letter.kpath_match?('NNL')
  end

  def test_create_letter
    login(:ant)
    assert node = secure!(Node) { Node.create_node(:title => 'my letter', :paper => 'Manila', :class => 'Letter', :parent_id => nodes_zip(:cleanWater)) }
    assert_equal "NNL", node.kpath
    assert_kind_of Note, node
    assert_kind_of VirtualClass, node.virtual_class
    assert_equal roles_id(:Letter), node.vclass_id
    assert_equal 'Letter', node.klass
    assert_equal 'Manila', node.paper
    assert node.vkind_of?('Letter')
    assert_equal "NNL", node.virtual_class[:kpath]
    assert_equal "NNL", node[:kpath]
  end

  def test_new_instance
    login(:ant)
    klass = roles(:Letter)
    assert node = secure!(Node) { klass.new_instance(:title => 'my letter', :parent_id => nodes_id(:cleanWater)) }
    assert node.save
    assert_kind_of Note, node
    assert !node.new_record?
    assert node.virtual_class
    assert_equal roles_id(:Letter), node.vclass_id
    assert_equal 'Letter', node.klass
    assert node.vkind_of?('Letter')
    assert_equal "NNL", node[:kpath]
  end

  def test_relation
    login(:ant)
    node = secure!(Node) { nodes(:zena) }
    #assert letters = node.find(:all,'letters')
    query = Node.build_query(:all, 'letters', :node_name => 'node')
    assert letters = Node.do_find(:all, eval(query.to_s))
    assert_equal 1, letters.size
    assert letters[0].vkind_of?('Letter')
    assert_kind_of Note, letters[0]
  end

  def test_superclass
    assert_equal Note, roles(:Post).superclass
    assert_equal Note, roles(:Letter).superclass
    assert_equal Page, roles(:Tracker).superclass
  end

  def test_new_conflict_virtual_kpath
    # add a sub class
    login(:lion)
    vclass = VirtualClass.create(:superclass => 'Note', :name => 'Pop', :create_group_id =>  groups_id(:public))
    assert !vclass.new_record?
    assert_not_equal Node.get_class('Post').kpath, vclass.kpath
    assert_equal 'NNO', vclass.kpath
  end

  def test_new_conflict_kpath
    # add a sub class
    login(:lion)
    vclass = VirtualClass.create(:superclass => 'Page', :name => 'Super', :create_group_id =>  groups_id(:public))
    assert !vclass.new_record?
    assert_not_equal Section.kpath, vclass.kpath
    assert_equal 'NPU', vclass.kpath
  end

  def test_update_name
    # add a sub class
    login(:lion)
    vclass = roles(:Post)
    assert_equal "NNP", vclass.kpath
    assert vclass.update_attributes(:name => 'Past')
    assert_equal "NNP", vclass.kpath
  end

  def test_update_superclass
    # add a sub class
    login(:lion)
    vclass = roles(:Post)
    assert_equal Note, vclass.superclass
    assert vclass.update_attributes(:superclass => 'Project')
    assert_equal Project, vclass.superclass
    assert_equal "NPPP", vclass.kpath
  end

  def test_auto_create_discussion
    assert !roles(:Letter).auto_create_discussion
    assert roles(:Post).auto_create_discussion
  end

  context 'Creating a virtual class' do
    setup do
      login(:lion)
    end

    context 'with a valid scope_index' do
      subject do
        {:name => 'Concert', :superclass => 'Project', :scope_index => 'IdxProject', :create_group_id => groups_id(:public) }
      end

      should 'create' do
        assert_difference('VirtualClass.count', 1) do
          VirtualClass.create(subject)
        end
      end
    end # with a valid scope_index

    context 'with an invalid scope_index' do
      subject do
        {:name => 'Concert', :superclass => 'Project', :scope_index => 'Page', :create_group_id => groups_id(:public) }
      end

      should 'not create' do
        assert_difference('VirtualClass.count', 0) do
          VirtualClass.create(subject)
        end
      end

      should 'add errors to scope_index' do
        vclass = VirtualClass.create(subject)
        assert_equal 'invalid model (should include ScopeIndex::IndexMethods)', vclass.errors[:scope_index]
      end
    end # with a valid scope_index
  end # Creating a virtual class

  context 'importing virtual class definitions' do
    setup do
      login(:lion)
    end

    context 'with an existing superclass' do
      setup do
        @data = {"Foo" => {'superclass' => 'Page'}}
      end

      should 'create a new virtual class with the given name' do
        res = nil
        assert_difference('VirtualClass.count', 1) do
          res = secure(VirtualClass) { VirtualClass.import(@data) }
        end
        assert_equal 'Foo', res.first.name
        assert_equal 'new', res.first.import_result
        assert_equal 'NPF', res.first.kpath
      end

      context 'and an existing virtual class' do
        setup do
          @data = {'Post' => {'superclass' => 'Note'}}
        end

        should 'update the virtual class if the superclass match' do
          res = nil
          assert_difference('VirtualClass.count', 0) do
            res = secure(VirtualClass) { VirtualClass.import(@data) }
          end
          assert_equal 'Post', res.first.name
          assert_equal 'same', res.first.import_result
          assert_equal 'NNP', res.first.kpath
        end

        context 'if the superclasses do not match' do
          setup do
            @data['Post']['superclass'] = 'Page'
          end

          should 'return a conflict error' do
            res = nil
            assert_difference('VirtualClass.count', 0) do
              res = secure(VirtualClass) { VirtualClass.import(@data) }
            end
            assert_equal 'Post', res.first.name
            assert_equal 'conflict', res.first.import_result
          end

          should 'propagate the conflict error to subclasses in the definitions' do
            @data['Foo'] = {'superclass' => 'Post'}
            @data['Bar'] = {'superclass' => 'Foo'}
            res = nil
            assert_difference('VirtualClass.count', 0) do
              res = secure(VirtualClass) { VirtualClass.import(@data) }
            end
            post = res.detect {|r| r.name == 'Post'}
            foo  = res.detect {|r| r.name == 'Foo'}
            bar  = res.detect {|r| r.name == 'Bar'}
            assert foo.new_record?
            assert_equal 'Foo', foo.name
            assert_equal 'conflict in superclass', foo.import_result
            assert_equal 'Post', post.name
            assert_equal 'conflict', post.import_result
            assert bar.new_record?
            assert_equal 'Bar', bar.name
            assert_equal 'conflict in superclass', bar.import_result
          end
        end
      end
    end # with an existing superclass

    context 'without an existing superclass' do
      setup do
        @data = {'Foo' => {'superclass' => 'Baz'}, 'Baz' => {'superclass' => 'Post'}}
      end

      should 'create the superclass first if it is in the definitions' do
        res = nil
        assert_difference('VirtualClass.count', 2) do
          res = secure(VirtualClass) { VirtualClass.import(@data) }
        end
        foo = res.detect {|r| r.name == 'Foo'}
        baz = res.detect {|r| r.name == 'Baz'}
        assert_equal 'Foo', foo.name
        assert_equal 'new', foo.import_result
        assert_equal 'NNPBF', foo.kpath
        assert_equal 'Baz', baz.name
        assert_equal 'new', baz.import_result
        assert_equal 'NNPB', baz.kpath
      end

      should 'return an error if the superclass is not in the definitions' do
        @data.delete('Baz')
        res = nil
        assert_difference('VirtualClass.count', 0) do
          res = secure(VirtualClass) { VirtualClass.import(@data) }
        end
        foo = res.first
        assert_equal 'Foo', foo.name
        assert_equal 'missing superclass', foo.import_result
      end
    end # without an existing superclass
  end # importing virtual class definitions
end
