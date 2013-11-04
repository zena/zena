require 'test_helper'

class AncestryTest < Zena::Unit::TestCase

  context 'On an object with a fullpath' do
    setup do
      login(:ant)
    end

    subject do
      secure(Node) { nodes(:status) }
    end

    context 'on fullpath_as_title' do
      should 'return path with titles' do
        assert_equal ["projects list", "Clean Water project", "Etat des travaux"], subject.fullpath_as_title
      end

      should 'return double dot from rel_path' do
        assert_equal '(../Clean Water project/Etat des travaux)', subject.pseudo_id(nodes(:wiki), :relative_path)
      end
    end # on fullpath_as_title

    context 'on short_path' do
      should 'return last two parent titles' do
        assert_equal ["..", "Clean Water project", "Etat des travaux"], subject.short_path
      end
    end # on short_path

    context 'and custom_base set' do
      subject do
        secure(Node) { nodes(:cleanWater) }
      end

      should 'set basepath' do
        assert_equal fullpath(:projects, :cleanWater), subject.basepath
      end

      should 'set basepath in children' do
        assert_equal fullpath(:projects, :cleanWater), nodes(:status).basepath
      end
    end # and custom_base set

    context 'with a secret parent' do
      subject do
        secure(Node) { nodes(:talk) }
      end

      should 'replace parent by star on fullpath_as_title' do
        assert_equal ["projects list", "*", "Talk"], subject.fullpath_as_title
      end

      should 'replace parent by star on short_path' do
        assert_equal ["..", "*", "Talk"], subject.short_path
      end
    end # with a secret parent

  end # On an object with a fullpath

  context 'Moving an object' do
    setup do
      login(:lion)
      subject.update_attributes(:parent_id => nodes_id(:lion))
    end

    subject do
      secure(Node) { nodes(:secret) }
    end

    should 'rebuild fullpath in new parent' do
      assert_equal fullpath(:zena, :people, :lion, :secret), subject.fullpath
    end

    should 'rebuild children fullpath' do
      assert_equal fullpath(:zena, :people, :lion, :secret, :talk), nodes(:talk).fullpath
      assert_equal fullpath(:zena, :people, :lion, :secret, :proposition), nodes(:proposition).fullpath
    end

    context 'with custom_base set' do
      subject do
        secure(Node) { nodes(:cleanWater) }
      end

      should 'rebuild basepath in new parent' do
        assert_equal fullpath(:people, :lion, :cleanWater), subject.basepath
      end

      should 'rebuild children basepath' do
        assert_equal fullpath(:people, :lion, :cleanWater), nodes(:status).basepath
      end
    end # with custom_base set


  end # Moving an object

  context 'Finding an object from a path' do
    setup do
      login(:lion)
    end

    subject do
      secure(Node) { Node.find_by_path('projects list/Secret/Talk')}
    end

    should 'find object' do
      assert_equal nodes_id(:talk), subject.id
    end

    context 'without access to secret parent' do
      setup do
        login(:anon)
      end

      should 'not find object' do
        assert_nil subject
      end
    end # without access to secret parent
    
    context 'without access to the object' do
      setup do
        login(:anon)
      end
      
      subject do
        secure(Node) { Node.find_by_path('projects list/Secret') }
      end

      should 'not find object' do
        assert_nil subject
      end
    end # without access to the object

  end # Finding an object

  context 'A node with ancestors' do
    subject do
      secure(Node) { nodes(:cleanWater) }
    end

    should 'return list of ancestors on ancestors' do
      assert_equal nodes_zip(:zena, :projects), subject.ancestors.map(&:zip)
    end
    
    should 'return true on is_ancestor in parent' do
      assert nodes(:projects).is_ancestor?(subject)
      assert nodes(:zena).is_ancestor?(subject)
    end
    
    should 'return true on is_ancestor in self' do
      assert subject.is_ancestor?(subject)
    end

    context 'with a zip starting like subject' do
      setup do
        subject.fullpath = '22'
        @node = secure(Node) { nodes(:people) }
        @node.fullpath = '2234'
      end

      should 'not return true on is_ancestor' do
        assert !subject.is_ancestor?(@node)
      end
    end # with an zip starting like subject
    
    should 'not return true on is_ancestor in foreign' do
      assert subject.is_ancestor?(subject)
    end
    
    context 'with a secret parent' do
      subject do
        secure(Node) { nodes(:talk) }
      end

      should 'skip secret parent in ancestors' do
        assert_equal nodes_zip(:zena, :projects), subject.ancestors.map(&:zip)
      end
    end # with a secret parent
  end # A node with ancestors

  context 'A visitor with write access' do
    setup do
      login(:tiger)
    end

    context 'creating a node' do
      subject do
        secure(Node) { Node.create(:parent_id => nodes_id(:projects), :title => 'Kyma')}
      end

      should 'build fullpath' do
        assert_equal [nodes_zip(:zena), nodes_zip(:projects), subject.zip].join('/'), subject.fullpath
      end

      should 'build basepath' do
        err subject
        assert_equal [nodes_zip(:zena), nodes_zip(:projects), subject.zip].join('/'), subject.fullpath
      end
    end # creating a node

  end # A visitor with write access


  context 'A node in an ancestry loop' do
    setup do
      login(:ant)
      Node.connection.execute "UPDATE nodes SET parent_id = #{nodes_id(:status)} WHERE id = #{nodes_id(:cleanWater)}"
    end

    subject do
      secure(Node) { nodes(:lake_jpg) }
    end

    should 'raise Invalid record on site rebuild_fullpath' do
      assert_raise(Zena::InvalidRecord) { current_site.rebuild_fullpath(subject.parent_id) }
    end
  end # A node in an ancestry loop


  private
    def fullpath(*args)
      args.map {|sym| nodes_zip(sym).to_s}.join('/')
    end
end