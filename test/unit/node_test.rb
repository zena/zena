# encoding: utf-8
require 'test_helper'

class NodeTest < Zena::Unit::TestCase

  NEW_DEFAULT = {
    :node_name => 'hello',
    :rgroup_id => Zena::FoxyParser::id('zena', 'public'),
    :wgroup_id => Zena::FoxyParser::id('zena', 'workers'),
    :dgroup_id => Zena::FoxyParser::id('zena', 'managers'),
    :parent_id => Zena::FoxyParser::id('zena', 'cleanWater'),
  }.freeze

  context 'On a node' do
    subject do
      secure!(Node) { nodes(:cleanWater) }
    end

    context 'with a sub-node' do
      should 'return true on ancestor?' do
        assert subject.ancestor?(secure!(Node) { nodes(:status) })
      end
    end # with a sub-node

    context 'with a node that is not a sub-node' do
      should 'return false on ancestor?' do
        assert !subject.ancestor?(secure!(Node) { nodes(:people) })
      end
    end # with a node that is not a sub-node

    should 'return true on ancestor? on self' do
      assert subject.ancestor?(subject)
    end
  end # On a node

  context 'A logged in user' do
    setup do
      login(:lion)
    end

    context 'on a node with write access' do
      subject do
        secure!(Node) { nodes(:lion) }
      end

      context 'adding a comment with m_title' do
        subject do
          node = secure!(Node) { nodes(:lion) }
          node.update_attributes(:m_title => 'Amartya Sen', :m_text => 'Equality of What')
          node
        end

        should 'create a Comment' do
          assert_difference('Comment.count', 1) do
            subject
          end
        end

        should 'set comment title from m_title' do
          assert_equal 'Amartya Sen', subject.comments.first.title
        end

        should 'set author from visitor' do
          assert_equal users_id(:lion), subject.comments.first.user_id
        end
      end # adding a comment with m_title

      context 'setting an indexed field' do
        subject do
          node = secure!(Node) { nodes(:art) }
          node.update_attributes(:origin => 'Dada')
          node
        end

        should 'create index entries' do
          assert_difference('IdxNodesString.count', 1) do
            subject
          end
        end

        should 'write field value in index' do
          subject
          index = IdxNodesString.find(:first, :conditions => {:key => 'origin', :node_id => subject.id})
          assert_equal 'origin', index.key
          assert_equal 'Dada', index.value
        end

        should 'keep index entries up to date' do
          subject

          assert_difference('IdxNodesString.count', 0) do
            subject.update_attributes(:origin => 'Surrealism')
          end

          index = IdxNodesString.find(:first, :conditions => {:key => 'origin', :node_id => subject.id})
          assert_equal 'origin', index.key
          assert_equal 'Surrealism', index.value
        end

        should 'find indexed nodes with exact search' do
          subject # create index entry
          assert node = Node.search_records(:origin => 'Dada').first
          assert_equal nodes_id(:art), node.id
        end

        should 'find indexed nodes with hash search' do
          subject # create index entry
          assert node = Node.search_records(:origin => 'Dada').first
          assert_equal nodes_id(:art), node.id
        end
      end # setting an indexed field
    end # on a node with write access
  end # A logged in user

  def test_rebuild_fullpath
    Node.connection.execute "UPDATE nodes SET fullpath = NULL, basepath = NULL WHERE id = #{nodes_id(:wiki)}"
    login(:ant)
    node = nodes(:wiki)
    assert_nil node[:fullpath]
    node.send(:rebuild_fullpath)
    assert_equal 'projects/wiki', node.fullpath
  end

  def test_rebuild_fullpath_in_custom_base
    Node.connection.execute "UPDATE nodes SET fullpath = NULL, basepath = NULL WHERE id = #{nodes_id(:status)}"
    login(:ant)
    node = nodes(:status)
    assert_nil node[:fullpath]
    node.send(:rebuild_fullpath)
    assert_equal 'projects/cleanWater/status', node.fullpath
  end

  def test_find_by_path
    login(:ant)
    node = secure!(Node) { Node.find_by_path('projects/wiki') }
    assert_equal nodes_id(:wiki), node.id
  end

  def test_match_query
    query = Node.match_query('smala')
    assert_equal "nodes.node_name LIKE 'smala%'", query[:conditions]
    query = Node.match_query('.', :node => nodes(:wiki))
    assert_equal ["parent_id = ?", nodes_id(:wiki)], query[:conditions]
  end

  def test_ancestors
    Node.connection.execute "UPDATE nodes SET parent_id = #{nodes_id(:proposition)} WHERE id = #{nodes_id(:bird_jpg)}"
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    assert_equal ['zena', 'projects', 'cleanWater'], node.ancestors.map { |a| a[:node_name] }
    node = secure!(Node) { nodes(:zena) }
    assert_equal [], node.ancestors
    node = secure!(Node) { nodes(:bird_jpg) }
    prop = secure!(Node) { nodes(:proposition)}
    assert_kind_of Node, prop
    assert prop.can_read?
    assert_equal ['zena', 'projects', 'secret', 'proposition'], node.ancestors.map { |a| a[:node_name] }
  end

  def test_ancestors_infinit_loop
    Node.connection.execute "UPDATE nodes SET parent_id = #{nodes_id(:status)} WHERE id = #{nodes_id(:cleanWater)}"
    login(:ant)
    node = secure!(Node) { nodes(:lake_jpg) }
    assert_raise(Zena::InvalidRecord) { node.ancestors }
  end

  def test_ancestor_in_hidden_project
    login(:tiger)
    node = secure!(Node) { nodes(:proposition) }
    assert_kind_of Node, node
    assert_equal ['zena', 'projects', 'secret'], node.ancestors.map { |a| a[:node_name] } # ant can view 'proposition' but not the project proposition is in
  end

  def test_create_simplest
    login(:ant)
    test_page = secure!(Node) { Node.create(:node_name => 'yoba', :parent_id => nodes_id(:cleanWater), :inherit=>1 ) }
    assert ! test_page.new_record? , "Not a new record"
    assert_equal nodes_id(:cleanWater), test_page.parent[:id]
    assert_equal 'projects/cleanWater/yoba', test_page.fullpath
    assert_equal 'projects/cleanWater', test_page.basepath
    parent = secure!(Node) { nodes(:cleanWater) }
    assert_equal 'projects/cleanWater', parent.fullpath
  end

  def test_new_bad_parent
    login(:tiger)
    attrs = NEW_DEFAULT.dup
    attrs[:parent_id] = nodes_id(:proposition)
    node = secure!(Page) { Page.new(attrs) }
    assert node.save , "Save ok"

    attrs[:parent_id] = nodes_id(:myDreams) # cannot write here
    node = secure!(Page) { Page.new(attrs) }
    assert ! node.save , "Save fails"
    assert node.errors[:parent_id].any?
    assert_equal 'invalid reference', node.errors[:parent_id]

    attrs[:parent_id] = nodes_id(:cleanWater) # other parent ok
    node = secure!(Page) { Page.new(attrs) }
    assert node.save , "Save succeeds"
  end

  def test_new_without_parent
    login(:tiger)
    attrs = NEW_DEFAULT.dup
    attrs.delete(:parent_id)
    node = secure!(Node) { Node.new(attrs) }
    assert ! node.save , "Save fails"
    assert node.errors[:parent_id].any?
    assert_equal 'invalid reference', node.errors[:parent_id]
    # page parent ok
    assert node.new_record?
    node = secure!(Node) { Node.new(attrs) }
    node.parent_id = nodes_id(:lake)
    assert node.save , "Save succeeds"
  end

  def test_page_new_without_node_name
    login(:tiger)
    node = secure!(Node) { Node.new(:parent_id => nodes_id(:cleanWater)) }
    assert ! node.save, 'Save fails'
    assert_equal 'can\'t be blank', node.errors[:node_name]
  end

  def test_new_set_section_id
    login(:tiger)
    node = secure!(Page) { Page.create(:parent_id => nodes_id(:people), :node_name => 'SuperPage')}
    assert ! node.new_record?, 'Not a new record'
    assert_equal nodes_id(:people), node[:section_id]
  end

  def toto_test_update_no_or_bad_parent
    login(:ant)
    node = secure!(Node) { nodes(:wiki) }
    assert_kind_of Node, node
    assert node.save , "Save succeeds"
    node.parent_id = nil
    assert ! node.save , "Save fails"
    assert node.errors[:parent_id].any?
    node = secure!(Node) { nodes(:wiki) }
    node.parent_id = nodes_id(:wiki)
    assert ! node.save , "Save fails"
    assert node.errors[:parent_id].any?
    node = secure!(Node) { nodes(:wiki) }
    node.parent_id = nodes_id(:cleanWater)
    assert ! node.save , "Save fails"
  end

  def test_update_bad_parent
    login(:tiger)
    node = secure!(Node) { nodes(:status)  }
    node[:parent_id] = nodes_id(:proposition)
    assert node.save , "Save ok"

    node = secure!(Node) { nodes(:status)  }
    node[:parent_id] = nodes_id(:myDreams) # cannot write here
    assert ! node.save , "Save fails"
    assert node.errors[:parent_id].any?
    assert_equal "invalid reference", node.errors[:parent_id]

    node = secure!(Node) { nodes(:status)  }
    node[:parent_id] = nodes_id(:projects) # parent ok
    assert node.save , "Save succeeds"
  end

  def test_page_update_without_node_name
    login(:tiger)
    node = secure!(Node) { nodes(:status)  }
    node[:node_name] = nil
    assert node.save, 'Save succeeds'
    assert_equal 'statusTitle', node[:node_name]
    node = secure!(Node) { nodes(:status)  }
    node[:node_name] = nil
    node.title = ""
    assert !node.save, 'Save fails'
    assert_equal 'can\'t be blank', node.errors[:node_name]
  end

  def test_update_set_section_id
    login(:tiger)
    node = secure!(Node) { Node.find(nodes_id(:lion))}
    assert_equal nodes_id(:people), node[:section_id]
    node[:parent_id]  = nodes_id(:zena)
    node[:section_id] = nodes_id(:status)
    assert node.save, 'Can save node'
    node.reload
    assert_equal nodes_id(:zena), node[:section_id]
  end

  def test_parent
    login(:anon)
    assert_equal nodes_id(:projects), secure!(Node) { nodes(:wiki) }.parent[:id]
  end

  def test_project
    login(:anon)
    assert_equal nodes_id(:zena), secure!(Node) { nodes(:people) }.project[:id]
    assert_equal nodes_id(:cleanWater), secure!(Node) { nodes(:cleanWater) }.project[:id]
    assert_equal nodes_id(:zena), secure!(Node) { nodes(:cleanWater) }.real_project[:id]
  end

  def test_section
    login(:tiger)
    assert_equal nodes_id(:people), secure!(Node) { nodes(:tiger) }.section[:id]
    assert_equal nodes_id(:cleanWater), secure!(Node) { nodes(:cleanWater) }.project[:id]
    assert_equal nodes_id(:zena), secure!(Node) { nodes(:cleanWater) }.real_project[:id]
  end

  def test_real_project
    login(:ant)
    node = secure!(Node) { nodes(:status) }
    assert_equal nodes_id(:cleanWater), node.project[:id]
    node = secure!(Node) { nodes(:cleanWater) }
    assert_equal nodes_id(:cleanWater), node.project[:id]
    assert_equal nodes_id(:zena), node.real_project[:id]
    assert_equal nodes_id(:zena), node.real_project.real_project[:id]
  end

  def test_real_section
    login(:tiger)
    node = secure!(Node) { nodes(:tiger) }
    assert_equal nodes_id(:people), node.section[:id]
    node = secure!(Node) { nodes(:people) }
    assert_equal nodes_id(:people), node.section[:id]
    assert_equal nodes_id(:zena), node.real_section[:id]
    assert_equal nodes_id(:zena), node.real_section.real_section[:id]
  end

  def test_new_child
    login(:ant)
    node = secure!(Node) { nodes(:cleanWater)  }
    child = node.new_child(:node_name => 'status', :class => Page )
    assert !child.save, "Save fails"
    assert child.errors[:node_name].any?

    child = node.new_child(:node_name => 'new_name', :class => Page )
    assert child.save , "Save succeeds"
    assert_equal Zena::Status[:red],  child.v_status
    assert_equal child[:user_id], users_id(:ant)
    assert_equal node[:dgroup_id], child[:dgroup_id]
    assert_equal node[:rgroup_id], child[:rgroup_id]
    assert_equal node[:wgroup_id], child[:wgroup_id]
    assert_equal node[:section_id], child[:section_id]
    assert_equal 1, child[:inherit]
    assert_equal node[:id], child[:parent_id]
  end

  def test_secure_find_by_path
    login(:tiger)
    node = secure!(Node) { Node.find_by_path('projects/secret') }
    assert_kind_of Node, node
    assert_kind_of User, node.instance_variable_get(:@visitor)
    login(:ant)
    assert_raise(ActiveRecord::RecordNotFound) { node = secure!(Node) { Node.find_by_path('projects/secret') }}
  end

  def test_author
    login(:tiger)
    node = secure!(Node) { nodes(:cleanWater) }
    assert_equal node.user.node_id, node.author[:id]
    assert_equal 'Panther Tigris Sumatran', node.author.fullname
    login(:anon)
    node = secure!(Node) { nodes(:status) }
    assert_equal 'Solenopsis Invicta', node.author.fullname
  end

  def test_set_node_name_with_title
    login(:tiger)
    node = secure!(Node) { Node.create(NEW_DEFAULT.stringify_keys.merge('node_name' => '', 'title' => 'small bed')) }
    assert_kind_of Node, node
    assert !node.new_record?
    assert_equal 'smallBed', node.node_name
  end

  def test_set_node_name
    node = nodes(:wiki)
    node.node_name = " J'aime l'aïl en août ! "
    assert_equal 'JAimeLAilEnAout', node.node_name
    node.node_name = "LIEUX"
    assert_equal 'LIEUX', node.node_name
  end

  def test_change_project_to_page
    login(:tiger)
    node = secure!(Node) { nodes(:cleanWater)  }
    assert node.update_attributes(:klass => 'Page')
    node = secure!(Node) { nodes(:cleanWater)  }
    assert_kind_of Page, node
    assert_equal 'NP', node[:kpath]
    assert_equal nodes_id(:zena), node.get_project_id
    assert_equal nodes_id(:zena), nodes(:status)[:project_id]
    assert_equal nodes_id(:zena), nodes(:lake)[:project_id]
  end
  #
  # def test_cannot_change_root
  #   login(:tiger)
  #   node = secure!(Node) { Node.find(visitor.site[:root_id]) }
  #   node = node.change_to(Page)
  #   assert_nil node
  #   node = secure!(Node) { Node.find(visitor.site[:root_id]) }
  #   assert_kind_of Section, node
  # end

  context 'A visitor in the drive group of the root node' do
    setup do
      login(:tiger)
      @node = secure!(Node) { nodes(:zena) }
    end

    should 'be allowed to change groups' do
      # root nodes do not have a parent_id !!
      # reference = self
      @node[:dgroup_id] = groups_id(:public)
      assert @node.save
    end

    should 'be allowed to change attributes' do
      assert @node.update_attributes(:node_name => 'vodou', :event_at => Time.now)
    end

    should 'not be allowed to set parent' do
      assert_nil @node[:parent_id]
      assert !@node.update_attributes(:parent_id => nodes_id(:status))
      assert_equal 'root should not have a parent', @node.errors[:parent_id]
    end
  end

  context 'A visitor with drive access' do
    setup do
      login(:tiger)
    end

    context 'on a published node with documents' do

      subject do
        secure!(Node) { nodes(:wiki) }
      end

      should 'see a published node with published documents' do
        assert_equal Zena::Status[:pub], subject.v_status
        assert_equal Zena::Status[:pub], versions(:bird_jpg_en).status
        assert_equal Zena::Status[:pub], versions(:flower_jpg_en).status
      end

      should 'unpublish documents when unpublishing node' do
        assert subject.unpublish
        assert_equal Zena::Status[:rem], versions(:bird_jpg_en).status
        assert_equal Zena::Status[:rem], versions(:flower_jpg_en).status
      end
    end

    context 'on a removed node with removed documents' do
      subject do
        node = secure!(Node) { nodes(:wiki) }
        node.unpublish
        node.reload
        node
      end

      should 'publish documents when publishing node' do
        assert subject.publish
        assert_equal Zena::Status[:pub], versions(:bird_jpg_en).status
        assert_equal Zena::Status[:pub], versions(:flower_jpg_en).status
      end
    end

    context 'on a redaction node with documents in redaction status' do
      subject do
        node = secure!(Node) { nodes(:wiki) }
        node.unpublish
        node.redit
        node.reload
        node
      end

      should 'see redactions' do
        assert_equal Zena::Status[:red], subject.v_status
        assert_equal Zena::Status[:red], versions(:bird_jpg_en).status
        assert_equal Zena::Status[:red], versions(:flower_jpg_en).status
      end

      should 'propose documents when proposing node' do
        assert subject.propose
        assert_equal Zena::Status[:prop_with], versions(:bird_jpg_en).status
        assert_equal Zena::Status[:prop_with], versions(:flower_jpg_en).status
      end
    end

    context 'on a proposition with proposed documents' do
      subject do
        node = secure!(Node) { nodes(:wiki) }
        node.unpublish
        node.redit
        node.propose
        node.reload
        node
      end

      should 'see propositions' do
        assert_equal Zena::Status[:prop], subject.v_status
        assert_equal Zena::Status[:prop_with], versions(:bird_jpg_en).status
        assert_equal Zena::Status[:prop_with], versions(:flower_jpg_en).status
      end

      should 'refuse documents when refusing node' do
        assert subject.refuse
        assert_equal Zena::Status[:red], versions(:bird_jpg_en).status
        assert_equal Zena::Status[:red], versions(:flower_jpg_en).status
      end
    end
  end


  def test_change_section_to_project
    login(:lion)
    node = secure!(Node) { nodes(:people)  }
    assert_equal node[:id], node.get_section_id
    assert_equal nodes_id(:zena), node.get_project_id

    assert node.update_attributes(:klass => "Project")
    node = secure!(Node) { nodes(:people)  }
    assert_kind_of Project, node
    assert_equal 'NPP', node[:kpath]

    assert_equal nodes_id(:zena), node.get_section_id
    assert_equal node[:id], node.get_project_id

    assert_equal nodes_id(:zena), nodes(:ant).get_section_id # children inherit new section_id
    assert_equal nodes_id(:zena), nodes(:myLife).get_section_id
    assert_equal node[:id], nodes(:ant).get_project_id # children inherit new project_id
    assert_equal node[:id], nodes(:myLife).get_project_id
  end

  def test_sync_section
    login(:tiger)
    node = secure!(Node) { nodes(:cleanWater) }
    assert_equal nodes_id(:zena), node[:section_id]
    node[:parent_id] = nodes_id(:projects)
    assert node.save
    assert_equal nodes_id(:zena), node[:section_id]
    assert_equal nodes_id(:zena), nodes(:cleanWater)[:section_id]
  end

  def test_sync_project_for_node
    login(:tiger)
    node = secure!(Node) { nodes(:people) }
    assert_equal nodes_id(:zena), node[:section_id]
    assert_equal nodes_id(:zena  ), node[:project_id]
    node[:parent_id] = nodes_id(:cleanWater)
    assert node.save
    assert_equal nodes_id(:cleanWater), node[:project_id]
    assert_equal nodes_id(:cleanWater), nodes(:people)[:project_id]
    assert_equal nodes_id(:zena      ), node[:section_id]
    assert_equal nodes_id(:zena      ), nodes(:people)[:section_id]
  end

  def test_sync_project_for_section
    login(:tiger)
    node = secure!(Node) { nodes(:people) }
    assert_equal nodes_id(:people), node.get_section_id
    assert_equal nodes_id(:zena  ), node[:project_id]
    node[:parent_id] = nodes_id(:cleanWater)
    assert node.save
    assert_equal nodes_id(:cleanWater), node[:project_id]
    assert_equal nodes_id(:cleanWater), nodes(:people)[:project_id]
    assert_equal nodes_id(:people), node.get_section_id
    assert_equal nodes_id(:zena), nodes(:people)[:section_id]
  end

  def test_all_children
    login(:tiger)
    assert_nothing_raised { secure!(Node) { nodes(:ant) }  }
    nodes  = secure!(Node) { nodes(:people).send(:all_children) }
    people = secure!(Node) { nodes(:people) }
    assert_equal 4, nodes.size
    assert_equal 4, people.find(:all, 'children').size
    assert_raise(NoMethodError) { people.all_children } # private method
  end

  def test_url_name
    assert_equal "salutJEcrisAujourdHui", "salut j'écris: Aujourd'hui ".url_name!
    assert_equal "a--BabMol", " à,--/ bab* mol".url_name!
    assert_equal "07.11.2006-mardiProchain", "07.11.2006-mardi_prochain".url_name!
    assert_equal "Node-+login", "Node-+login".url_name!
  end

  def test_tags
    login(:lion)
    @node = secure!(Node) { nodes(:status)  }
    assert_nothing_raised { @node.find(:all, 'set_tags') }
    assert_nil @node.find(:all, 'set_tags')
    @node.rel['set_tag'].other_ids = [nodes_id(:art),nodes_id(:news)]
    assert @node.save
    tags = @node.find(:all, 'set_tags')
    assert_equal 2, tags.size
    assert_equal 'art', tags[0].node_name
    assert_equal 'news', tags[1].node_name
    @node.rel['set_tag'].other_ids = [nodes_id(:art)]
    @node.save
    tags = @node.find(:all, 'set_tags')
    assert_equal 1, tags.size
    assert_equal 'art', tags[0].node_name
  end

  def test_tag_update
    login(:lion)
    node = secure!(Node) { nodes(:art) }
    assert node.update_attributes('tagged_ids' => [nodes_id(:status), nodes_id(:people)])
    assert_equal 2, node.find(:all, 'tagged', :skip_rubyless => true).size
    stat = secure!(Node) { nodes(:status) }
    peop = secure!(Node) { nodes(:people) }
    assert_equal node[:id], stat.find(:first, 'set_tags')[:id]
    assert_equal node[:id], peop.find(:first, 'set_tags')[:id]
  end

  def test_after_all_cache_sweep
    with_caching do
      login(:lion)
      i = 1
      assert_equal "content 1", Cache.with(visitor.id, visitor.group_ids, 'NP', 'pages')  { "content #{i}" }
      assert_equal "content 1", Cache.with(visitor.id, visitor.group_ids, 'NN', 'notes')  { "content #{i}" }
      i = 2
      assert_equal "content 1", Cache.with(visitor.id, visitor.group_ids, 'NP', 'pages')  { "content #{i}" }
      assert_equal "content 1", Cache.with(visitor.id, visitor.group_ids, 'NN', 'notes')  { "content #{i}" }

      # do something on a project
      node = secure!(Node) { nodes(:wiki) }
      assert_equal 'NPP', node.class.kpath
      assert node.update_attributes(:title=>'new title'), "Can change attributes"
      # sweep only kpath NPP
      i = 3
      assert_equal "content 3", Cache.with(visitor.id, visitor.group_ids, 'NP', 'pages')  { "content #{i}" }
      assert_equal "content 1", Cache.with(visitor.id, visitor.group_ids, 'NN', 'notes')  { "content #{i}" }

      # do something on a note
      node = secure!(Node) { nodes(:proposition) }
      assert_equal 'NNP', node.vclass.kpath
      assert node.update_attributes(:node_name => 'popo' ), "Can change attributes"
      # sweep only kpath NN
      i = 4
      assert_equal "content 3", Cache.with(visitor.id, visitor.group_ids, 'NP', 'pages')  { "content #{i}" }
      assert_equal "content 4", Cache.with(visitor.id, visitor.group_ids, 'NN', 'notes')  { "content #{i}" }
    end
  end

  def test_empty_comments
    login(:tiger)
    node = secure!(Node) { nodes(:lake) }
    assert node.discussion
    assert_nil node.comments
  end

  def test_discussion_lang
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    assert_equal Zena::Status[:pub], node.v_status
    discussion = node.discussion
    assert_kind_of Discussion, discussion
    assert_equal discussions_id(:outside_discussion_on_status_en), discussion[:id]
    login(:ant)
    node = secure!(Node) { nodes(:status) }
    discussion = node.discussion
    assert discussion.new_record?, "New discussion"
    assert_equal 'fr', discussion.lang
    assert discussion.open?
    assert !discussion.inside?
  end

  def test_closed_discussion
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    discussion = node.discussion
    discussion.update_attributes(:open=>false)
    node = secure!(Node) { nodes(:status) }
    assert_equal discussions_id(:outside_discussion_on_status_en), node.discussion[:id]
    login(:ant)
    node = secure!(Node) { nodes(:status) }
    assert_nil node.discussion
    node.update_attributes( :title=>'test' )
    discussion = node.discussion
    assert_kind_of Discussion, discussion
    assert discussion.inside?
  end

  def test_inside_discussion
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    node.update_attributes( :title=>'new status' )
    assert_equal Zena::Status[:red], node.v_status
    discussion = node.discussion
    assert_equal discussions_id(:inside_discussion_on_status), discussion[:id]
  end

  def test_auto_create_discussion
    login(:tiger)
    post   = secure!(Node) { Node.create_node(:v_status => Zena::Status[:pub], :title => 'a new post', :class => 'Post', :parent_id => nodes_zip(:cleanWater)) }
    letter = secure!(Node) { Node.create_node(:v_status => Zena::Status[:pub], :title => 'a letter', :class => 'Letter', :parent_id => nodes_zip(:cleanWater)) }
    assert !post.new_record?, "Not a new record"
    assert !letter.new_record?, "Not a new record"
    assert_equal Zena::Status[:pub], post.v_status, "Published"
    assert_equal Zena::Status[:pub], letter.v_status, "Published"
    assert !letter.discussion
    assert post.discussion
    assert !post.discussion.new_record?
    login(:anon)
    letter = secure!(Node) { Node.find(letter.id) }
    post   = secure!(Node) { Node.find(post.id) }
    assert !letter.can_comment?
    assert post.can_comment?
  end

  def test_auto_create_discussion
    login(:tiger)
    letter = secure!(Node) { Node.create_node(:v_status => Zena::Status[:pub], :title => 'a letter', :class => 'Letter', :parent_id => nodes_zip(:cleanWater)) }
    assert !letter.new_record?, "Not a new record"
    assert_equal Zena::Status[:pub], letter.v_status, "Published"
    login(:lion)
    letter = secure!(Node) { Node.find(letter.id) }
    assert letter.can_auto_create_discussion?
    assert Discussion.create(:node_id=>letter[:id], :lang=>'fr', :inside=>false)
    # there is an open discussion in another lang
    assert letter.can_auto_create_discussion?
  end

  def test_comments
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    comments = node.comments
    assert_kind_of Comment, comments[0]
    assert_equal 'Nice site', comments[0][:title]
  end

  def test_comments_on_nil
    login(:ant)
    node = secure!(Node) { nodes(:cleanWater) }
    assert_nil node.discussion # no open discussion here
    assert_equal nil, node.comments
  end

  def test_site_id
    login(:tiger)
    node = secure!(Node) { Node.create(NEW_DEFAULT) }
    err node
    assert !node.new_record?, "Not a new record"
    assert_equal sites_id(:zena), node[:site_id]
  end

  def test_other_site_id
    login(:whale)
    node = secure!(Node) { Node.create(:parent_id => nodes_id(:ocean), :rgroup_id => groups_id(:aqua), :wgroup_id => groups_id(:masters), :dgroup_id => groups_id(:masters), :node_name => "fish") }
    assert !node.new_record?, "Not a new record"
    assert_equal sites_id(:ocean), node[:site_id]
  end

  def test_other_site_id_fool_id
    login(:whale)
    node = secure!(Node) { Node.create(:parent_id => nodes_id(:ocean), :rgroup_id => groups_id(:aqua), :wgroup_id => groups_id(:masters), :dgroup_id => groups_id(:masters), :node_name => "fish", :site_id => sites_id(:zena)) }
    assert !node.new_record?, "Not a new record"
    assert_equal sites_id(:ocean), node[:site_id]
  end

  def test_cannot_set_site_id
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    original_site_id = node.site_id
    node.update_attributes(:site_id => 1234 )
    assert_equal original_site_id, node.site_id
  end

  def test_cannot_set_site_id_with_new_record
    login(:tiger)
    node = Node.new(:site_id => 1234)
    assert_nil node.site_id
  end

  def test_zip
    next_zip = Zena::Db.fetch_attribute("SELECT zip FROM zips WHERE site_id = #{sites_id(:zena)}").to_i
    login(:tiger)
    node = secure!(Node) { Node.create(:parent_id=>nodes_id(:zena), :node_name => "fly")}
    assert !node.new_record?, "Not a new record"
    assert_equal (next_zip + 1), node.zip
  end

  def test_find_by_zip
    login(:tiger)
    assert_raise(ActiveRecord::RecordNotFound) { node = secure!(Node) { Node.find_by_zip(99) } }
    assert_kind_of Node, secure!(Node) { Node.find_by_zip(nodes_zip(:cleanWater)) }
  end

  def test_parent_zip
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    parent = node.parent
    assert_equal nodes_id( :cleanWater), parent[:id]
    assert_equal nodes_zip(:cleanWater), node.parent_zip
  end

  def test_create_node
    login(:ant)
    node = secure!(Node) { Node.create_node(:parent_id => nodes_zip(:secret), :node_name => 'funny') }
    assert_equal nodes_id(:secret), node[:parent_id]
    assert node.new_record?, "Not saved"
    assert_equal 'invalid reference', node.errors[:parent_id]
  end

  def test_create_node_with__parent_id
    login(:ant)
    node = secure!(Node) { Node.create_node(:_parent_id => nodes_id(:secret), :node_name => 'funny') }
    assert_equal nodes_id(:secret), node[:parent_id]
    assert node.new_record?, "Not saved"
    assert_equal 'invalid reference', node.errors[:parent_id]
  end

  def test_create_node_ok
    login(:tiger)
    node = secure!(Node) { Node.create_node('parent_id' => nodes_zip(:cleanWater), 'node_name' => 'funny') }
    assert_equal nodes_id(:cleanWater), node[:parent_id]
    assert_equal 'funny', node[:node_name]
    assert !node.new_record?
  end

  def test_create_or_update_node_create
    login(:tiger)
    node = secure!(Node) { Node.create_or_update_node('parent_id' => nodes_zip(:cleanWater), 'node_name' => 'funny') }
    assert_equal nodes_id(:cleanWater), node[:parent_id]
    assert_equal 'funny', node[:node_name]
    assert !node.new_record?, "Saved"
  end

  def test_create_or_update_node_update
    login(:tiger)
    node = secure!(Node) { Node.create_or_update_node('parent_id' => nodes_zip(:cleanWater), 'node_name' => 'status', 'title'=>"It's all broken") }
    assert_equal nodes_id(:cleanWater), node[:parent_id]
    assert_equal nodes_id(:status), node[:id]
    node = secure!(Node) { nodes(:status) }
    assert_equal 'status', node[:node_name]
    assert_equal "It's all broken", node.title
  end

  def test_create_with_klass
    login(:tiger)
    node = secure!(Node) { Node.create_node('parent_id' => nodes_zip(:projects), 'node_name' => 'funny', 'klass' => 'TextDocument', 'content_type' => 'application/x-javascript') }
    assert_kind_of TextDocument, node
    assert_equal nodes_id(:projects), node[:parent_id]
    assert_equal 'funny', node[:node_name]
    assert !node.new_record?, "Saved"
  end

  def test_get_class
    assert_equal Node, Node.get_class('node')
    assert_equal Node, Node.get_class('nodes')
    assert_equal Node, Node.get_class('Node')
    assert_equal roles(:Letter), Node.get_class('Letter')
    assert_equal TextDocument, Node.get_class('TextDocument')
  end

  def test_get_class_without_plural
    login(:lion)
    vclass = VirtualClass.create(:superclass => 'Project', :name => 'Process', :create_group_id =>  groups_id(:public))
    assert_equal vclass, Node.get_class('Process')
  end

  def test_get_attributes_from_yaml
    f = Tempfile.new('any.yml')
    path = f.path
    File.open(path, 'w') do |file|
      path = file.path
      file.puts "first: I am the first
five: 5
done: \"I am done\""
    end
    attrs = Node.get_attributes_from_yaml(path)

    assert_equal 'I am the first', attrs['first']
    assert_equal 5,                attrs['five']
    assert_equal 'I am done',      attrs['done']
  end

  def test_create_nodes_from_gzip_file
    login(:tiger)
    parent = secure!(Project) { Project.create(:node_name => 'import', :parent_id => nodes_id(:zena)) }
    assert !parent.new_record?, "Not a new record"
    nodes = secure!(Node) { Node.create_nodes_from_folder(:archive => uploaded_archive('simple.zml.gz'), :parent_id => parent[:id] )}.values
    assert_equal 1, nodes.size
    simple = nodes[0]
    assert_kind_of Note, simple
    assert_equal roles(:Post), simple.vclass
    assert !simple.new_record?
  end

  def test_create_nodes_from_folder_with_defaults
    login(:tiger)
    parent = secure!(Project) { Project.create(:node_name => 'import', :parent_id => nodes_id(:zena), :rgroup_id => groups_id(:managers), :wgroup_id => groups_id(:managers)) }
    assert !parent.new_record?, "Not a new record"
    result = secure!(Node) { Node.create_nodes_from_folder(:folder => File.join(Zena::ROOT, 'test', 'fixtures', 'import'), :parent_id => parent[:id] )}.values
    assert_equal 4, result.size

    children = parent.find(:all, 'children order by node_name asc')
    assert_equal 2, children.size
    assert_equal 'Photos', children[0].node_name
    assert_equal groups_id(:managers), children[0].rgroup_id
    assert_equal 'simple', children[1].node_name
    assert_equal groups_id(:managers), children[1].rgroup_id

    # we use children[1] as parent just to use any empty node
    result = secure!(Node) { Node.create_nodes_from_folder(:folder => File.join(Zena::ROOT, 'test', 'fixtures', 'import'), :parent_id => children[1][:id], :defaults => { :rgroup_id => groups_id(:public) } )}.values
    assert_equal 4, result.size

    children = children[1].find(:all, 'children order by node_name ASC')
    assert_equal 2, children.size
    assert_equal 'Photos', children[0].node_name
    assert_equal groups_id(:public), children[0].rgroup_id
  end

  def test_create_nodes_from_folder_with_publish
    login(:tiger)
    nodes = secure!(Node) { Node.create_nodes_from_folder(:folder => File.join(Zena::ROOT, 'test', 'fixtures', 'import'), :parent_id => nodes_id(:zena) )}.values
    assert_equal Zena::Status[:red], nodes[0].v_status

    nodes = secure!(Node) { Node.create_nodes_from_folder(:folder => File.join(Zena::ROOT, 'test', 'fixtures', 'import'), :parent_id => nodes_id(:cleanWater), :defaults => { :v_status => Zena::Status[:pub] }) }.values
    assert_equal Zena::Status[:pub], nodes[0].v_status
  end

  def test_create_nodes_from_archive
    login(:tiger)
    res = secure!(Node) { Node.create_nodes_from_folder(:archive => uploaded_archive('import.tgz'), :parent_id => nodes_id(:zena)) }.values
    photos = secure!(Section) { Section.find_by_node_name('Photos') }
    assert_kind_of Section, photos
    bird = secure!(Node) { Node.find_by_parent_id_and_node_name(photos[:id], 'bird') }
    assert_kind_of Image, bird
    assert_equal 56183, bird.size
    assert_equal 'Lucy in the sky', bird.text
    visitor.lang = 'fr'
    bird = secure!(Node) { Node.find_by_parent_id_and_node_name(photos[:id], 'bird') }
    assert_equal 'Le septième ciel', bird.text
    assert_equal 1, bird[:inherit]
    assert_equal groups_id(:public), bird[:rgroup_id]
    assert_equal groups_id(:workers), bird[:wgroup_id]
    assert_equal groups_id(:managers), bird[:dgroup_id]

    simple = secure!(Node) { Node.find_by_parent_id_and_node_name(nodes_id(:zena), 'simple') }
    assert_equal 0, simple[:inherit]
    assert_equal groups_id(:managers), simple[:rgroup_id]
    assert_equal groups_id(:managers), simple[:wgroup_id]
    assert_equal groups_id(:managers), simple[:dgroup_id]
  end

  def test_create_nodes_from_zip_archive
    login(:tiger)
    res = secure!(Node) { Node.create_nodes_from_folder(:archive => uploaded_zip('letter.zip'), :parent_id => nodes_id(:zena), :class => 'Letter') }.values
    res.sort!{|a,b| a.node_name <=> b.node_name}
    letter, bird = res[1], res[0]
    assert_kind_of Note, letter
    assert_equal 'Letter', letter.klass
  end

  def test_update_nodes_from_archive
    preserving_files('test.host/data') do
      bird = node = nil
      login(:tiger)
      node = secure!(Page) { Page.create(:parent_id => nodes_id(:status), :title => 'Photos', :text => '![]!') }
      assert !node.new_record?
      assert_nothing_raised { node = secure!(Node) { Node.find_by_path('projects/cleanWater/status/Photos') } }
      assert_raise(ActiveRecord::RecordNotFound) { node = secure!(Node) { Node.find_by_path( 'projects/cleanWater/status/Photos/bird') } }
      assert_no_match %r{I took during my last vacations}, node.text
      v1_id = node.version.id
      secure!(Node) { Node.create_nodes_from_folder(:archive => uploaded_archive('import.tgz'), :parent_id => nodes_id(:status)) }
      assert_nothing_raised { node = secure!(Node) { Node.find_by_path('projects/cleanWater/status/Photos') } }
      assert_nothing_raised { bird = secure!(Node) { Node.find_by_path('projects/cleanWater/status/Photos/bird') } }
      assert_match %r{I took during my last vacations}, node.text
      assert_equal v1_id, node.version.id
      assert_kind_of Image, bird
    end
  end

  def test_to_yaml
    #test_site('zena')
    login(:tiger)
    visitor.time_zone = 'Asia/Jakarta'
    assert_equal 'Asia/Jakarta', visitor.time_zone
    status = secure!(Node) { nodes(:status) }
    assert status.update_attributes_with_transformation(:v_status => Zena::Status[:pub], :text => "This is a \"link\":#{nodes_zip(:projects)}.", :origin => "A picture: !#{nodes_zip(:bird_jpg)}!")
    yaml = status.to_yaml
    assert_match %r{text:\s+\"?This is a "link":\(\.\./\.\.\)\.}, yaml
    assert_match %r{origin:\s+\"?A picture: !\(\.\./\.\./wiki/bird\)!}, yaml
    assert_no_match %r{log_at}, yaml
  end

  def test_to_yaml_with_change_log_at
    login(:tiger)
    visitor.time_zone = 'Asia/Jakarta'
    prop = secure!(Node) { nodes(:proposition) }
    assert prop.update_attributes_with_transformation(:v_status => Zena::Status[:pub], :text => "This is a \"link\":#{nodes_zip(:projects)}.", :origin => "A picture: !#{nodes_zip(:bird_jpg)}!", :log_at => "2008-10-20 14:53")
    assert_equal Time.gm(2008,10,20,7,53), prop.log_at
    yaml = prop.to_yaml
    assert_match %r{text:\s+\"?This is a "link":\(\.\./\.\.\)\.}, yaml
    assert_match %r{origin:\s+\"?A picture: !\(\.\./\.\./wiki/bird\)!}, yaml
    assert_match %r{log_at:\s+\"?2008-10-20 14:53:00\"?$}, yaml
  end

  def test_order_position
    login(:tiger)
    parent = secure!(Node) { nodes(:cleanWater) }
    children = parent.find(:all, 'children')
    assert_equal 8, children.size
    assert_equal 'bananas', children[0].node_name
    assert_equal 'crocodiles', children[1].node_name

    Node.connection.execute "UPDATE nodes SET position = -1.0 WHERE id = #{nodes_id(:water_pdf)}"
    Node.connection.execute "UPDATE nodes SET position = -0.5 WHERE id = #{nodes_id(:lake)}"
    children = parent.find(:all, 'children')
    assert_equal 8, children.size
    assert_equal 'water', children[0].node_name
    assert_equal 'lakeAddress', children[1].node_name
  end

  def test_plural_relation
    assert Node.plural_relation?('pages')
    assert Node.plural_relation?('children')
    assert ! Node.plural_relation?('parent')
    assert ! Node.plural_relation?('project')
    assert Node.plural_relation?('projects')
    assert Node.plural_relation?('posts')
    assert ! Node.plural_relation?('post')
    assert Node.plural_relation?('tags')
    assert Node.plural_relation?('tagged')
  end

  def test_classes_for_form
    Node.get_class('Tag')
    assert_equal [
      ["Page", "Page"],
      ["  Project", "Project"],
      ["  Section", "Section"],
      ["    Skin", "Skin"],
      ["  Tag", "Tag"],
     ], Node.classes_for_form(:class=>'Page', :without=>'Document')
  end

  def test_change_to_classes_for_form
    Node.get_class('Tag')
    assert_equal [
      ["Page", "Page"],
      ["  Project", "Project"],
      ["  Section", "Section"],
      ["    Skin", "Skin"],
      ["  Tag", "Tag"],
    ], Project.classes_for_form(:class=>'Page', :without=>'Document')
  end

  def test_allowed_change_to_classes
    Node.get_class('Tag')
    node_changes = Node.allowed_change_to_classes.reject{|k| k[/Dummy/]} # In case we are testing after Secure
    assert_equal %w{Node Note Letter Post Page Project Section Skin Tag Reference Contact}, node_changes

    assert_equal node_changes, Page.allowed_change_to_classes.reject{|k| k[/Dummy/]}
    assert_equal node_changes, Project.allowed_change_to_classes.reject{|k| k[/Dummy/]}
    assert_equal node_changes, Note.allowed_change_to_classes.reject{|k| k[/Dummy/]}

    assert_equal %w{Document TextDocument Template}, Document.allowed_change_to_classes.reject{|k| k[/Dummy/]}

    assert_equal ["Image"], Image.allowed_change_to_classes.reject{|k| k[/Dummy/]}
  end

  def test_match_one_node_only
    login(:tiger)
    match = secure!(Node) { Node.find(:all, Node.match_query('opening')) }
    assert_equal 1, match.size
    assert_equal nodes_id(:opening), match[0][:id]
  end

  def test_data
    login(:ant)
    node = secure!(Node) { nodes(:cleanWater) }
    entries = node.data
    assert_equal 4, entries.size
    assert_equal BigDecimal.new("13.0"), entries[2].value
    node = secure!(Node) { nodes(:tiger) }
    assert_nil node.data
    assert_nil node.data_b
  end

  def test_data_d
    login(:ant)
    node = secure!(Node) { nodes(:cleanWater) }
    entries = node.data_d
    assert_equal 1, entries.size
    assert_equal BigDecimal.new("56"), entries[0].value
  end

  context 'A class\' native classes hash' do
    should 'be indexed by kpath' do
      assert_equal [], %w{N ND NDI NDT NDTT NN NP NPP NPS NPSS NR NRC NU NUS} - Node.native_classes.keys
      assert_equal [], %w{ND NDI NDT NDTT} - Document.native_classes.keys
    end

    should 'should point to real (ruby) sub-classes and self' do
      assert Page.native_classes.values.include?(Page)
      assert Page.native_classes.values.include?(Project)
      assert !Project.native_classes.values.include?(Page)
    end
  end

  context 'A node' do
    setup do
      login(:tiger)
      @status = secure!(Node){nodes(:status)}
      @proposition = secure!(Node){nodes(:proposition)}
    end

    should 'respond true to vkind_of if it contains a class (real or virtual) in its hierarchy' do
      assert @status.vkind_of?('Page')
      assert @proposition.vkind_of?('Post')
    end

    should 'not respond true to vkind_of if it does not contain the class in its heirarchy' do
      assert !@status.vkind_of?('Document')
      assert !@status.vkind_of?('Post')
    end
  end

  context 'A class (real or virtual)' do
    should 'be found from its kpath' do
      assert_equal Node, Node.get_class_from_kpath('N')
      assert_equal Page, Node.get_class_from_kpath('NP')
      assert_equal Image, Node.get_class_from_kpath('NDI')
      assert_equal roles(:Post), Node.get_class_from_kpath('NNP')
      assert_equal roles(:Letter), Node.get_class_from_kpath('NNL')
      assert_equal TextDocument, Node.get_class_from_kpath('NDT')
    end
  end


  def test_position_on_create
    login(:lion)
    node = secure!(Page) { Page.create(:node_name => "yoba", :parent_id => nodes_id(:cleanWater), :inherit=>1 ) }
    assert !node.new_record?
    assert_equal 0.0, node.position
    assert node.update_attributes(:position => 5.0)
    assert_equal 5.0, node.position
    node = secure!(Page) { Page.find_by_id(node.id) } # reload
    assert_equal 5.0, node.position
    node = secure!(Page) { Page.create(:node_name => "babo", :parent_id => nodes_id(:cleanWater), :inherit=>1 ) }
    assert !node.new_record?
    assert_equal 6.0, node.position

    # position has different scopes depending on first two letters of kpath: 'ND', 'NN', 'NP', 'NR'
    doc = secure!(Document) { Document.create( :parent_id=>nodes_id(:cleanWater),
                                              :file  => uploaded_fixture('water.pdf', 'application/pdf', 'wat'), :title => "lazy waters.pdf") }
    assert !doc.new_record?
    assert_equal 0.0, doc.position

    # move
    assert node.update_attributes(:parent_id => nodes_id(:wiki))
    assert_equal 0.0, node.position

    # move a page
    node = secure!(Node) { nodes(:art)}
    assert_equal 0.0, node.position
    assert node.update_attributes(:parent_id => nodes_id(:cleanWater))
    assert_equal 6.0, node.position

    # move a document
    node = secure!(Node) { nodes(:bird_jpg)}
    assert_equal 0.0, node.position
    assert node.update_attributes(:parent_id => nodes_id(:cleanWater))
    assert_equal 0.0, node.position
  end

  def test_custom_a
    login(:lion)
    node = secure!(Node) { nodes(:status) }
    assert_nil node.custom_a
    assert node.update_attributes(:custom_a => 10)

    node = secure!(Node) { nodes(:status) }
    assert_equal 10, node.custom_a

    assert node.update_attributes(:custom_a => '')

    node = secure!(Node) { nodes(:status) }
    assert_nil node.custom_a
  end

  def test_replace_attributes_in_values
    login(:lion)
    node = secure!(Node) { nodes(:status) }
    new_attributes = node.replace_attributes_in_values(:foo => 'id: #{id}, title: #{title}')
    assert_equal "id: 22, title: status title", new_attributes[:foo]
  end

  def test_copy
    login(:lion)
    node = secure!(Node) { nodes(:status) }
    attributes = {
      :copy_id => nodes_zip(:bird_jpg),
      :icon_id => '#{id}',
      :m_title => 'Changed icon to "#{title}"',
      :m_text  => 'By #{visitor.login}'
    }

    new_attributes = secure(Node) { Node.transform_attributes(attributes) }
    assert_equal Hash['icon_id' => nodes_id(:bird_jpg),
                      'm_title' => 'Changed icon to "bird"',
                      'm_text'  => 'By lion'], new_attributes

    assert node.update_attributes_with_transformation(attributes)
    assert_equal nodes_id(:bird_jpg), node.find(:first, 'icon')[:id]
  end

  def test_export
    without_files('/test.host/tmp') do
      login(:tiger)
      export_folder = File.join(SITES_ROOT, 'test.host', 'tmp')
      FileUtils::mkpath(export_folder)
      # Add a page and a text document into 'wiki'
      assert secure!(Node) { Node.create(:title=>"Hello World!", :text => "Bonjour", :parent_id => nodes_id(:wiki), :inherit=>1 ) }
      assert secure!(TextDocument) { TextDocument.create(:node_name => "yoba", :parent_id => nodes_id(:wiki), :text => "#header { color:red; }\n#footer { color:blue; }", :content_type => 'text/css') }
      wiki = secure!(Node) { nodes(:wiki) }
      assert_equal 4, wiki.find(:all, "children").size
      wiki.export_to_folder(export_folder)
      assert File.exist?(File.join(export_folder, 'wiki.zml'))
      assert File.exist?(File.join(export_folder, 'wiki'))
      assert File.exist?(File.join(export_folder, 'wiki', 'bird.jpg'))
      assert !File.exist?(File.join(export_folder, 'wiki', 'bird.zml'))
      assert File.exist?(File.join(export_folder, 'wiki', 'flower.jpg'))
      assert !File.exist?(File.join(export_folder, 'wiki', 'flower.zml'))
      assert File.exist?(File.join(export_folder, 'wiki', 'yoba.css'))
      assert !File.exist?(File.join(export_folder, 'wiki', 'yoba.zml'))
      assert File.exist?(File.join(export_folder, 'wiki', 'HelloWorld.zml'))
    end
  end

  def test_archive
    without_files('/test.host/tmp') do
      login(:tiger)
      export_folder = File.join(SITES_ROOT, 'test.host', 'tmp')
      FileUtils::mkpath(export_folder)
      # Add a page and a text document into 'wiki'
      assert secure!(Node) { Node.create(:title=>"Hello World!", :text => "Bonjour", :parent_id => nodes_id(:wiki), :inherit=>1 ) }
      assert secure!(TextDocument) { TextDocument.create(:node_name => "yoba", :parent_id => nodes_id(:wiki), :text => "#header { color:red; }\n#footer { color:blue; }", :content_type => 'text/css') }
      wiki = secure!(Node) { nodes(:wiki) }
      assert_equal 4, wiki.find(:all, "children").size
      archive = wiki.archive
      `tar -C '#{export_folder}' -xz < '#{archive.path}'`
      assert File.exist?(File.join(export_folder, 'wiki.zml'))
      assert File.exist?(File.join(export_folder, 'wiki'))
      assert File.exist?(File.join(export_folder, 'wiki', 'bird.jpg'))
      assert !File.exist?(File.join(export_folder, 'wiki', 'bird.zml'))
      assert File.exist?(File.join(export_folder, 'wiki', 'flower.jpg'))
      assert !File.exist?(File.join(export_folder, 'wiki', 'flower.zml'))
      assert File.exist?(File.join(export_folder, 'wiki', 'yoba.css'))
      assert !File.exist?(File.join(export_folder, 'wiki', 'yoba.zml'))
      assert File.exist?(File.join(export_folder, 'wiki', 'HelloWorld.zml'))
    end
  end

  def test_translate_pseudo_id
    login(:lion)
    { '11'                        => nodes_id(:zena),
      nodes_zip(:cleanWater).to_i => nodes_id(:cleanWater),
      nodes_zip(:status)          => nodes_id(:status)
    }.each do |k,v|
      assert_equal v, secure(Node) { Node.translate_pseudo_id(k) }, "'#{k}' should translate to '#{v}'"
    end
  end

  def test_translate_pseudo_id_path
    login(:lion)
    lion       = secure!(Node) { nodes(:lion) }
    people     = secure!(Node) { nodes(:people) }
    cleanWater = secure!(Node) { nodes(:cleanWater) }
    assert lion.update_attributes(:title => 'status', :v_status => Zena::Status[:pub])
    assert_equal 'people/status', lion.fullpath
       # path                           base_node
    { ['(/projects/cleanWater/status)', nil]  => nodes_id(:status),
      ['(/projects/cleanWater/status)', people]  => nodes_id(:status),
      ['(status)', people]      => nodes_id(:lion),
      ['(status)', cleanWater]  => nodes_id(:status),
    }.each do |k,v|
      assert_equal v, secure(Node) { Node.translate_pseudo_id(k[0],:id,k[1]) }, "'#{k.inspect}' should translate to '#{v}'"
    end
  end

  def test_unparse_assets
    login(:lion)
    @node = secure!(Node) { nodes(:status) }
    assert @node.update_attributes(:text => "Hello this is \"art\":#{nodes_zip(:art)}. !#{nodes_zip(:bird_jpg)}!")
    assert_equal "Hello this is \"art\":(../../../collections/art). !(../../wiki/bird)!", @node.unparse_assets(@node.text, self, 'text')
  end

  def test_parse_assets
    login(:lion)
    @node = secure!(Node) { nodes(:status) }
    assert @node.update_attributes(:text => "Hello this is \"art\":(../../../collections/art).")
    assert_equal "Hello this is \"art\":#{nodes_zip(:art)}.", @node.parse_assets(@node.text, self, 'text')
  end

  context 'Finding safe method type' do
    context 'for safe methods in class' do
      should 'return method name' do
        ['m_text', 'inherit', 'l_status', 'l_comment', 'm_text', 'inherit', 'v_status'].each do |k|
          assert_equal k, Page.safe_method_type([k])[:method]
        end
      end
    end

    context 'for methods not declared as safe in the class' do
      should 'return nil' do
        ['puts', 'raise', 'blah', 'system'].each do |k|
          assert_nil Page.safe_method_type([k])
        end
      end
    end

    context 'for id' do
      should 'return zip' do
        assert_equal Hash[:class=>Number, :method=>'zip'], Page.safe_method_type(['id'])
      end
    end

    context 'for relation pseudo-methods' do
      should 'use rel and try' do
        ['hot_status', 'blah_comment', 'blah_zips', 'blah_id', 'blah_ids'].each do |k|
          assert_match %r{rel\[.#{k.gsub(/_.+/,'')}.\]\.try}, Page.safe_method_type([k])[:method]
        end
      end
    end

    context 'for safe properties' do
      should 'return version and method name when safe' do
        ['text', 'title'].each do |k|
          assert_equal "prop['#{k}']", Page.safe_method_type([k])[:method]
        end
      end

      should 'return nil when unsafe' do
        ['first_name', 'name'].each do |k|
          assert_nil Node.safe_method_type([k])
        end
      end
    end
  end

  # FIXME: write test
  def test_assets
    print 'P'
    # sweep_cache (save) => remove asset folder
    # render math ?
  end

  def find_node_by_pseudo(string, base_node = nil)
    secure(Node) { Node.find_node_by_pseudo(string, base_node || @node) }
  end

  def assert_transforms(result, src)
    if src.kind_of?(Hash)
      assert_equal result, secure(Node) { Node.transform_attributes( src ) }
    else
      assert_equal result, secure(Node) { Node.transform_attributes( 'text' => src )['text'] }
    end
  end

  context 'Transforming attributes' do
    context 'with non-ISO date format' do
      setup do
        I18n.locale = 'fr'
        visitor.time_zone = 'Asia/Jakarta'
      end

      subject do
        '9-9-2009 15:17'
      end

      should 'parse event_at date' do
        assert_transforms Hash['event_at' => Time.utc(2009,9,9,8,17)], Hash['event_at' => '9-9-2009 15:17']
      end

      should 'parse log_at date' do
        assert_transforms Hash['log_at' => Time.utc(2009,9,9,8,17)], Hash['log_at' => '9-9-2009 15:17']
      end
    end

    context 'with zazen content' do
      setup do
        login(:lion)
      end

      should 'parse pseudo ids' do
        assert_transforms "Hi, this is just a simple \"test\":25 or \"\":29_life.rss. OK ?\n\n!24_pv!",
                          "Hi, this is just a simple \"test\"::w or \"\"::w+_life.rss. OK ?\n\n!:lake+_pv!"
      end

      should 'parse pseudo ids with offset in gallery' do
        assert_transforms "Hi ![30,24]! ![]!",
                          "Hi ![30,:lake+]! ![]!"
      end

      should 'parse pseudo ids in doc_list' do
        assert_transforms "Hi !{30,24}! !{}!",
                          "Hi !{:bird,:lake+}! !{}!"

      end

      should 'parse pseudo ids in links' do
        assert_transforms "Hi !30!:21 !30!:21 !30/nice bird!:21 !30_pv/hello ladies!:21",
                          "Hi !30!::clean !:bird!::clean !:bird/nice bird!:21 !30_pv/hello ladies!:21"
      end

      should 'not alter existing code without pseudo ids' do
        assert_transforms "Hi, this is normal "":1/ just a\n\n* asf\n* asdf ![23,33]!",
                          "Hi, this is normal "":1/ just a\n\n* asf\n* asdf ![23,33]!"
      end
    end # with zazen content

    context 'with ids' do
      setup do
        login(:tiger)
      end

      should 'parse pseudo_ids in parent_id' do
        assert_transforms Hash['parent_id' => nodes_id(:lake_jpg)],
                          Hash['parent_id' => 'lake+']
      end

      should 'parse pseudo_ids in links' do
        assert_transforms Hash['tag_ids' => [nodes_id(:art), nodes_id(:news)]],
                          Hash['tag_ids' => '33,news']
      end

      should 'leave single bad ids' do
        assert_transforms Hash['parent_id' => '999', 'hot_id' => '999'],
                          Hash['parent_id' => '999', 'hot_id' => '999']
      end

      should 'remove bad values from id lists' do
        assert_transforms Hash['tag_ids' => [nodes_id(:news),nodes_id(:art)]],
                          Hash['tag_ids' => '999,34,art']
      end

      should 'parse dates and ids in rel' do
        # this should be 14:58 when #255 is fixed (tz support).
        assert_transforms Hash['link' => {'hot' => {'other_id' => nodes_id(:status), 'date' => Time.gm(2009,7,15,16,58)}}],
                          Hash['link' => {'hot' => {'other_id' => '22', 'date' => '2009-7-15 16:58' }}]
      end
    end # with ids
  end # Transforming attributes

  def test_parse_keys
    node = secure(Node) { nodes(:status) }
    assert_equal %w{archive problems summary text title}, node.parse_keys.sort

    note = secure(Node) { nodes(:opening) }
    assert_equal %w{text title}, note.parse_keys.sort
  end

  def test_safe_send
    node = secure(Node) { nodes(:status) }
    assert_equal 'safe_send("title")', RubyLess.translate(Node, 'send("title")')

    assert_equal 'status title', node.safe_send("title")
    assert_equal nodes_zip(:status).to_s, node.safe_send("id")
    assert_equal nil, node.safe_send("object_id")
  end
end