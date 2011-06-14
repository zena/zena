# encoding: utf-8
require 'test_helper'

class NodeTest < Zena::Unit::TestCase

  NEW_DEFAULT = {
    :title     => 'hello',
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
      should 'return true on is_ancestor?' do
        assert subject.is_ancestor?(secure!(Node) { nodes(:status) })
      end
    end # with a sub-node

    context 'with a node that is not a sub-node' do
      should 'return false on is_ancestor?' do
        assert !subject.is_ancestor?(secure!(Node) { nodes(:people) })
      end
    end # with a node that is not a sub-node

    should 'return true on is_ancestor? on self' do
      assert subject.is_ancestor?(subject)
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

      context 'setting with transformations' do
        subject do
          secure(Node) { nodes(:letter) }
        end

        should 'transform zip in parent_id' do
          assert subject.update_attributes_with_transformation('parent_id' => 'lake+')
          assert_equal nodes_id(:lake), subject.parent_id
        end

        should 'add error on bad zip in parent_id' do
          assert !subject.update_attributes_with_transformation('parent_id' => '999')
          assert_equal 'could not be found', subject.errors['parent_id']
        end

        should 'create links from pseudo ids' do
          assert_difference('Link.count', 2) do
            assert subject.update_attributes_with_transformation('set_tag_ids' => '33,news')
            assert_equal [nodes_id(:art), nodes_id(:news)], subject.rel['set_tag'].other_ids
          end
        end

        should 'add errors for bad ids' do
          assert_difference('Link.count', 0) do
            assert !subject.update_attributes_with_transformation('set_tag_ids' => '33,news,999,11')
            assert_match %r'11 => invalid target', subject.errors['set_tag']
            assert_match %r'999 => could not be found', subject.errors['set_tag']
          end
        end
      end # setting with transformations

    end # on a node with write access
  end # A logged in user

  # This is a stupid test because the result is not the same in production...
  def test_match_query
    query = Node.match_query('smala')
    assert_equal "vs.idx_text_high LIKE '%smala%'", query[:conditions]
    query = Node.match_query('.', :node => nodes(:wiki))
    assert_equal ["parent_id = ?", nodes_id(:wiki)], query[:conditions]
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

  def test_page_new_without_title
    login(:tiger)
    node = secure!(Node) { Node.new(:parent_id => nodes_id(:cleanWater)) }
    assert ! node.save, 'Save fails'
    assert_equal 'can\'t be blank', node.errors[:title]
  end

  def test_new_set_section_id
    login(:tiger)
    node = secure!(Page) { Page.create(:parent_id => nodes_id(:people), :title => 'SuperPage')}
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

  def test_page_update_without_title
    login(:tiger)
    node = secure!(Node) { nodes(:status)  }
    node.title = nil
    assert !node.save
    assert_equal 'can\'t be blank', node.errors[:title]
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

    child = node.new_child(:title => 'new_name', :class => Page )
    assert child.save , "Save succeeds"
    assert_equal Zena::Status::Red,  child.v_status
    assert_equal child[:user_id], users_id(:ant)
    assert_equal node[:dgroup_id], child[:dgroup_id]
    assert_equal node[:rgroup_id], child[:rgroup_id]
    assert_equal node[:wgroup_id], child[:wgroup_id]
    assert_equal node[:section_id], child[:section_id]
    assert_equal 1, child[:inherit]
    assert_equal node[:id], child[:parent_id]
  end

  def test_author
    login(:tiger)
    node = secure!(Node) { nodes(:cleanWater) }
    assert_equal node.user.node_id, node.author[:id]
    assert_equal 'Panthera Tigris Sumatran', node.author.title
    login(:anon)
    node = secure!(Node) { nodes(:status) }
    assert_equal 'Solenopsis Invicta', node.author.title
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
      assert @node.update_attributes(:event_at => Time.now)
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
        assert_equal Zena::Status::Pub, subject.v_status
        assert_equal Zena::Status::Pub, versions(:bird_jpg_en).status
        assert_equal Zena::Status::Pub, versions(:flower_jpg_en).status
      end

      should 'unpublish documents when unpublishing node' do
        assert subject.unpublish
        assert_equal Zena::Status::Rem, versions(:bird_jpg_en).status
        assert_equal Zena::Status::Rem, versions(:flower_jpg_en).status
      end

      should 'sync documents with node' do
        assert subject.unpublish
        assert_equal Zena::Status::Rem, versions(:bird_jpg_en).status
        assert_equal Zena::Status::Rem, versions(:flower_jpg_en).status
        assert subject.redit
        assert_equal Zena::Status::Red, versions(:bird_jpg_en).status
        assert_equal Zena::Status::Red, versions(:flower_jpg_en).status
        assert subject.publish
        assert_equal Zena::Status::Pub, versions(:bird_jpg_en).status
        assert_equal Zena::Status::Pub, versions(:flower_jpg_en).status
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
        assert_equal Zena::Status::Pub, versions(:bird_jpg_en).status
        assert_equal Zena::Status::Pub, versions(:flower_jpg_en).status
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
        assert_equal Zena::Status::Red, subject.v_status
        assert_equal Zena::Status::Red, versions(:bird_jpg_en).status
        assert_equal Zena::Status::Red, versions(:flower_jpg_en).status
      end

      should 'propose documents when proposing node' do
        assert subject.propose
        assert_equal Zena::Status::PropWith, versions(:bird_jpg_en).status
        assert_equal Zena::Status::PropWith, versions(:flower_jpg_en).status
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
        assert_equal Zena::Status::Prop, subject.v_status
        assert_equal Zena::Status::PropWith, versions(:bird_jpg_en).status
        assert_equal Zena::Status::PropWith, versions(:flower_jpg_en).status
      end

      should 'refuse documents when refusing node' do
        assert subject.refuse
        assert_equal Zena::Status::Red, versions(:bird_jpg_en).status
        assert_equal Zena::Status::Red, versions(:flower_jpg_en).status
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
    assert_equal "salut-j%27%C3%A9cris%3A-Aujourd%27hui-", "salut j'écris: Aujourd'hui ".url_name
    assert_equal "07.11.2006%2Dmardi%5Fprochain", "07.11.2006-mardi_prochain".url_name
    ['avant-hier', 'un ami ', 'èààèüï a', '" à,--/ bab* mol'].each do |l|
      assert_equal l, String.from_url_name(l.url_name)
    end
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
    assert_equal 'Art', tags[0].title
    assert_equal 'News list', tags[1].title
    @node.rel['set_tag'].other_ids = [nodes_id(:art)]
    @node.save
    tags = @node.find(:all, 'set_tags')
    assert_equal 1, tags.size
    assert_equal 'Art', tags[0].title
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

  def test_empty_comments
    login(:tiger)
    node = secure!(Node) { nodes(:lake) }
    assert node.discussion
    assert_nil node.comments
  end

  def test_discussion_lang
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    assert_equal Zena::Status::Pub, node.v_status
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

  context 'A node with a discussion' do
    setup do
      login(:tiger)
      visitor.lang = 'fr'
      subject.update_attributes('title' => 'new publication', :v_status => Zena::Status::Pub)
      subject.reload
    end

    subject do
      # has an open discussion in 'en'
      secure(Node) { nodes(:status) }
    end

    context 'visited in another language without discussion' do
      setup do
        login(:ant)
      end

      should 'create an outside discussion' do
        assert_kind_of Discussion, subject.discussion
        assert !subject.discussion.inside?
      end
    end # visited in another language

    context 'that is closed' do
      setup do
        discussions(:outside_discussion_on_status_en).update_attributes(:open => false)
      end

      context 'visited in another language without discussion without drive access' do
        setup do
          login(:ant)
        end

        should 'not create a discussion' do
          assert_nil subject.discussion
        end
      end # visited in another language
    end # that is closed

  end # A node with a closed discussion

  def test_inside_discussion
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    node.update_attributes( :title=>'new status' )
    assert_equal Zena::Status::Red, node.v_status
    discussion = node.discussion
    assert_equal discussions_id(:inside_discussion_on_status), discussion[:id]
  end

  def test_auto_create_discussion
    login(:tiger)
    post   = secure!(Node) { Node.create_node(:v_status => Zena::Status::Pub, :title => 'a new post', :class => 'Post', :parent_id => nodes_zip(:cleanWater)) }
    letter = secure!(Node) { Node.create_node(:v_status => Zena::Status::Pub, :title => 'a letter', :class => 'Letter', :parent_id => nodes_zip(:cleanWater)) }
    assert !post.new_record?, "Not a new record"
    assert !letter.new_record?, "Not a new record"
    assert_equal Zena::Status::Pub, post.v_status, "Published"
    assert_equal Zena::Status::Pub, letter.v_status, "Published"
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
    letter = secure!(Node) { Node.create_node(:v_status => Zena::Status::Pub, :title => 'a letter', :class => 'Letter', :parent_id => nodes_zip(:cleanWater)) }
    assert !letter.new_record?, "Not a new record"
    assert_equal Zena::Status::Pub, letter.v_status, "Published"
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
    assert_equal 'Nice site', comments[0].title
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
    node = secure!(Node) { Node.create(:parent_id => nodes_id(:ocean), :rgroup_id => groups_id(:aqua), :wgroup_id => groups_id(:masters), :dgroup_id => groups_id(:masters), :title => "fish") }
    assert !node.new_record?, "Not a new record"
    assert_equal sites_id(:ocean), node[:site_id]
  end

  def test_other_site_id_fool_id
    login(:whale)
    node = secure!(Node) { Node.create(:parent_id => nodes_id(:ocean), :rgroup_id => groups_id(:aqua), :wgroup_id => groups_id(:masters), :dgroup_id => groups_id(:masters), :title => "fish", :site_id => sites_id(:zena)) }
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
    node = secure!(Node) { Node.create(:parent_id=>nodes_id(:zena), :title => "fly")}
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
    node = secure!(Node) { Node.create_node(:parent_id => nodes_zip(:secret), :title => 'funny') }
    assert node.new_record?, "Not saved"
    assert_equal 'invalid reference', node.errors[:parent_id]
  end

  def test_create_node_with__parent_id
    login(:ant)
    node = secure!(Node) { Node.create_node(:_parent_id => nodes_id(:secret), :title => 'funny') }
    assert node.new_record?, "Not saved"
    assert_equal 'invalid reference', node.errors[:parent_id]
  end

  def test_create_node_ok
    login(:tiger)
    node = secure!(Node) { Node.create_node('parent_id' => nodes_zip(:cleanWater), 'title' => 'funny') }
    assert_equal nodes_id(:cleanWater), node[:parent_id]
    assert_equal 'funny', node.title
    assert !node.new_record?
  end

  context 'Create or update from parent and title' do
    setup do
      login(:tiger)
    end

    context 'with matching node' do
      subject do
        secure(Node) { Node.create_or_update_node('parent_id' => nodes_zip(:cleanWater), 'title' => 'crocodiles', 'text' => 'Philippine crocodile') }
      end

      should 'update found node' do
        assert_difference('Node.count', 0) do
          assert subject.errors.blank?
          assert_equal nodes_id(:crocodiles), subject.id
          assert_equal 'Philippine crocodile', subject.prop['text']
        end
      end
    end # with matching node

    context 'without a matching node' do
      subject do
        secure(Node) { Node.create_or_update_node('parent_id' => nodes_zip(:cleanWater), 'title' => 'scorpion', 'text' => 'Compsobuthus werneri') }
      end

      should 'create a new node' do
        assert_difference('Node.count', 1) do
          err subject
        end
      end
    end # without a matching node

  end # Create or update from parent and title

  def test_create_with_klass
    login(:tiger)
    node = secure!(Node) { Node.create_node('parent_id' => nodes_zip(:projects), 'title' => 'funny', 'klass' => 'TextDocument', 'content_type' => 'application/x-javascript') }
    assert_kind_of TextDocument, node
    assert_equal nodes_id(:projects), node[:parent_id]
    assert_equal 'funny', node.title
    assert !node.new_record?, "Saved"
  end

  def test_get_class
    assert_equal Node, Node.get_class('node').real_class
    assert_equal Node, Node.get_class('nodes').real_class
    assert_equal Node, Node.get_class('Node').real_class
    assert_equal roles(:Letter), Node.get_class('Letter')
    assert_equal TextDocument, Node.get_class('TextDocument').real_class
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
    parent = secure!(Project) { Project.create(:title => 'import', :parent_id => nodes_id(:zena)) }
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
    parent = secure!(Project) { Project.create(:title => 'import', :parent_id => nodes_id(:zena), :rgroup_id => groups_id(:managers), :wgroup_id => groups_id(:managers)) }
    assert !parent.new_record?, "Not a new record"
    result = secure!(Node) { Node.create_nodes_from_folder(:folder => File.join(Zena::ROOT, 'test', 'fixtures', 'import'), :parent_id => parent.id )}.values
    assert_equal 4, result.size

    children = parent.find(:all, 'nodes order by title asc')
    assert_equal 2, children.size
    assert_equal 'Photos !', children[0].title
    assert_equal groups_id(:managers), children[0].rgroup_id
    assert_equal 'simple', children[1].title
    assert_equal groups_id(:managers), children[1].rgroup_id

    # we use children[1] as parent just to use any empty node
    result = secure!(Node) { Node.create_nodes_from_folder(:folder => File.join(Zena::ROOT, 'test', 'fixtures', 'import'), :parent_id => children[1][:id], :defaults => { :rgroup_id => groups_id(:public) } )}.values
    assert_equal 4, result.size

    children = children[1].find(:all, 'nodes order by title ASC')
    assert_equal 2, children.size
    assert_equal 'Photos !', children[0].title
    assert_equal groups_id(:public), children[0].rgroup_id
  end

  def test_create_nodes_from_folder_with_publish
    login(:tiger)
    nodes = secure!(Node) { Node.create_nodes_from_folder(:folder => File.join(Zena::ROOT, 'test', 'fixtures', 'import'), :parent_id => nodes_id(:zena) )}.values
    assert_equal Zena::Status::Red, nodes[0].v_status

    nodes = secure!(Node) { Node.create_nodes_from_folder(:folder => File.join(Zena::ROOT, 'test', 'fixtures', 'import'), :parent_id => nodes_id(:cleanWater), :defaults => { :v_status => Zena::Status::Pub }) }.values
    assert_equal Zena::Status::Pub, nodes[0].v_status
  end

  def test_create_nodes_from_archive
    login(:tiger)
    res = secure(Node) { Node.create_nodes_from_folder(:archive => uploaded_archive('import.tgz'), :parent_id => nodes_id(:zena)) }.values
    photos = secure!(Section) { Section.first(:conditions => {:_id => 'Photos !'}) }
    assert_kind_of Section, photos
    bird = secure!(Node) { Node.find_by_parent_id_and__id(photos[:id], 'bird') }
    assert_kind_of Image, bird
    assert_equal 56183, bird.size
    assert_equal 'Lucy in the sky', bird.text
    visitor.lang = 'fr'
    bird = secure!(Node) { Node.find_by_parent_id_and__id(photos[:id], 'bird') }
    assert_equal 'Le septième ciel', bird.text
    assert_equal 1, bird[:inherit]
    assert_equal groups_id(:public), bird[:rgroup_id]
    assert_equal groups_id(:workers), bird[:wgroup_id]
    assert_equal groups_id(:managers), bird[:dgroup_id]

    simple = secure!(Node) { Node.find_by_parent_id_and__id(nodes_id(:zena), 'simple') }
    assert_equal 0, simple[:inherit]
    assert_equal groups_id(:managers), simple[:rgroup_id]
    assert_equal groups_id(:managers), simple[:wgroup_id]
    assert_equal groups_id(:managers), simple[:dgroup_id]
  end

  context 'With an archive' do
    setup do
      login(:tiger)
    end

    subject do
      secure(Node) { Node.create_nodes_from_folder(
        :archive   => uploaded_archive('import.tgz'),
        :parent_id => nodes_id(:status)).values
      }
    end

    should 'create new entries' do
      assert_difference('Node.count', 4) do
        subject
      end
    end

    context 'updating existing pages' do
      setup do
        @photos = secure!(Page) { Page.create(:parent_id => nodes_id(:status), :title => 'Photos !', :text => '![]!') }
      end

      should 'create missing entries' do
        assert_difference('Node.count', 3) do
          subject
        end
      end

      should 'create entries of correct type' do
        subject
        assert_kind_of Image, secure(Node) { Node.find_by_parent_title_and_kpath(@photos.id, 'bird')}
      end

      should 'update existing entries' do
        subject
        assert_match %r{I took during my last vacations}, @photos.reload.text
      end
    end # updating existing pages

    context 'with specified class' do
      subject do
        secure(Node) { Node.create_nodes_from_folder(
          :archive => uploaded_zip('letter.zip'),
          :parent_id => nodes_id(:zena),
          :class => 'Letter').values
        }
      end

      should 'create with correct vclass' do
        letter = subject.detect {|n| n.title == 'letter'}
        assert_kind_of Note, letter
        assert_equal 'Letter', letter.klass
      end
    end # with instances of vclass

  end # With an archive

  def test_to_yaml
    #test_site('zena')
    login(:tiger)
    visitor.time_zone = 'Asia/Jakarta'
    assert_equal 'Asia/Jakarta', visitor.time_zone
    status = secure!(Node) { nodes(:status) }
    assert status.update_attributes_with_transformation(:v_status => Zena::Status::Pub, :text => "This is a \"link\":#{nodes_zip(:projects)}.", :origin => "A picture: !#{nodes_zip(:bird_jpg)}!")
    yaml = status.to_yaml
    assert_match %r{text:\s+\"?This is a "link":\(\.\./\.\.\)\.}, yaml
    assert_match %r{origin:\s+\"?A picture: !\(\.\./\.\./a wiki with Zena/bird\)!}, yaml
    assert_no_match %r{log_at}, yaml
  end

  def test_to_yaml_with_change_log_at
    login(:tiger)
    visitor.time_zone = 'Asia/Jakarta'
    prop = secure!(Node) { nodes(:proposition) }
    assert prop.update_attributes_with_transformation(:v_status => Zena::Status::Pub, :text => "This is a \"link\":#{nodes_zip(:projects)}.", :origin => "A picture: !#{nodes_zip(:bird_jpg)}!", :log_at => "2008-10-20 14:53")
    assert_equal Time.gm(2008,10,20,7,53), prop.log_at
    yaml = prop.to_yaml
    assert_match %r{text:\s+\"?This is a "link":\(\.\./\.\.\)\.}, yaml
    assert_match %r{origin:\s+\"?A picture: !\(\.\./\.\./a wiki with Zena/bird\)!}, yaml
    assert_match %r{log_at:\s+\"?2008-10-20 14:53:00\"?$}, yaml
  end

  def test_order_position
    login(:tiger)
    parent = secure!(Node) { nodes(:collections) }
    # default sort is position/title
    # ["Art", "News list", "Stranger in the night", "Top menu", "wiki skin"]
    children = parent.find(:all, 'children')
    assert_equal 5, children.size
    assert_equal nodes_id(:art), children[0].id
    assert_equal nodes_id(:news), children[1].id

    Node.connection.execute "UPDATE nodes SET position = -1.0 WHERE id = #{nodes_id(:menu)}"
    Node.connection.execute "UPDATE nodes SET position = -0.5 WHERE id = #{nodes_id(:strange)}"
    children = parent.find(:all, 'children')
    assert_equal 5, children.size
    assert_equal nodes_id(:menu), children[0].id
    assert_equal nodes_id(:strange), children[1].id
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
      ["    Blog", "Blog"],
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
      ["    Blog", "Blog"],
      ["  Section", "Section"],
      ["    Skin", "Skin"],
      ["  Tag", "Tag"],
    ], Project.classes_for_form(:class=>'Page', :without=>'Document')
  end

  def test_allowed_change_to_classes
    Node.get_class('Tag')
    node_changes = Node.allowed_change_to_classes.reject{|k| k[/Dummy/]} # In case we are testing after Secure
    assert_equal %w{Node Note Letter Post Page Project Blog Section Skin Tag Reference Contact}, node_changes

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

  context 'Finding real classes' do
    context 'by kpath' do
      should 'find class' do
        assert_equal Page, Node.native_classes['NP']
        assert_equal Document, Node.native_classes['ND']
        assert_equal Image, Node.native_classes['NDI']
      end

      should 'return nil for vclass kpath' do
        assert_nil Node.native_classes['NNP']
      end
    end # by kpath

    context 'by name' do
      should 'find class' do
        assert_equal Page, Node.native_classes_by_name['Page']
        assert_equal Document, Node.native_classes_by_name['Document']
        assert_equal Image, Node.native_classes_by_name['Image']
      end

      should 'return nil for vclass kpath' do
        assert_nil Node.native_classes['Post']
      end
    end # by name
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
      assert_equal VirtualClass['Node'], VirtualClass.find_by_kpath('N')
      assert_equal VirtualClass['Page'], VirtualClass.find_by_kpath('NP')
      assert_equal VirtualClass['Image'], VirtualClass.find_by_kpath('NDI')
      assert_equal roles(:Post), VirtualClass.find_by_kpath('NNP')
      assert_equal roles(:Letter), VirtualClass.find_by_kpath('NNL')
      assert_equal VirtualClass['TextDocument'], VirtualClass.find_by_kpath('NDT')
    end
  end


  def test_position_on_create
    login(:lion)
    node = secure!(Page) { Page.create(:title => "yoba", :parent_id => nodes_id(:cleanWater), :inherit=>1 ) }
    assert !node.new_record?
    assert_equal 0.0, node.position
    assert node.update_attributes(:position => 5.0)
    assert_equal 5.0, node.position
    node = secure!(Page) { Page.find_by_id(node.id) } # reload
    assert_equal 5.0, node.position
    node = secure!(Page) { Page.create(:title => "babo", :parent_id => nodes_id(:cleanWater), :inherit=>1 ) }
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
      'copy_id' => nodes_zip(:bird_jpg),
      'icon_id' => '#{id}',
      'parent_id' => '#{id}',
      'm_title' => 'Changed icon to "#{title}"',
      'm_text'  => 'By #{visitor.login}'
    }

    new_attributes = secure(Node) { Node.transform_attributes(attributes) }
    assert_equal Hash['icon_zip'  => nodes_zip(:bird_jpg).to_s,
                      'parent_zip'=> nodes_zip(:bird_jpg).to_s,
                      'm_title'   => 'Changed icon to "bird"',
                      'm_text'    => 'By lion'], new_attributes

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
      assert secure!(TextDocument) { TextDocument.create(:title => "yoba", :parent_id => nodes_id(:wiki), :text => "#header { color:red; }\n#footer { color:blue; }", :content_type => 'text/css') }
      wiki = secure!(Node) { nodes(:wiki) }
      assert_equal 4, wiki.find(:all, "children").size
      wiki.export_to_folder(export_folder)
      assert File.exist?(File.join(export_folder, 'a wiki with Zena.zml'))
      assert File.exist?(File.join(export_folder, 'a wiki with Zena'))
      assert File.exist?(File.join(export_folder, 'a wiki with Zena', 'bird.jpg'))
      assert !File.exist?(File.join(export_folder, 'a wiki with Zena', 'bird.zml'))
      assert File.exist?(File.join(export_folder, 'a wiki with Zena', 'flower.jpg'))
      assert !File.exist?(File.join(export_folder, 'a wiki with Zena', 'flower.zml'))
      assert File.exist?(File.join(export_folder, 'a wiki with Zena', 'yoba.css'))
      assert !File.exist?(File.join(export_folder, 'a wiki with Zena', 'yoba.zml'))
      assert File.exist?(File.join(export_folder, 'a wiki with Zena', 'Hello World!.zml'.to_filename))
    end
  end

  def test_archive
    without_files('/test.host/tmp') do
      login(:tiger)
      export_folder = File.join(SITES_ROOT, 'test.host', 'tmp')
      FileUtils::mkpath(export_folder)
      # Add a page and a text document into 'wiki'
      assert secure!(Node) { Node.create(:title=>"Hello World!", :text => "Bonjour", :parent_id => nodes_id(:wiki), :inherit=>1 ) }
      assert secure!(TextDocument) { TextDocument.create(:title => "yoba", :parent_id => nodes_id(:wiki), :text => "#header { color:red; }\n#footer { color:blue; }", :content_type => 'text/css') }
      wiki = secure!(Node) { nodes(:wiki) }
      assert_equal 4, wiki.find(:all, "children").size
      archive = wiki.archive
      `tar -C '#{export_folder}' -xz < '#{archive.path}'`
      assert File.exist?(File.join(export_folder, 'a wiki with Zena.zml'))
      assert File.exist?(File.join(export_folder, 'a wiki with Zena'))
      assert File.exist?(File.join(export_folder, 'a wiki with Zena', 'bird.jpg'))
      assert !File.exist?(File.join(export_folder, 'a wiki with Zena', 'bird.zml'))
      assert File.exist?(File.join(export_folder, 'a wiki with Zena', 'flower.jpg'))
      assert !File.exist?(File.join(export_folder, 'a wiki with Zena', 'flower.zml'))
      assert File.exist?(File.join(export_folder, 'a wiki with Zena', 'yoba.css'))
      assert !File.exist?(File.join(export_folder, 'a wiki with Zena', 'yoba.zml'))
      assert File.exist?(File.join(export_folder, 'a wiki with Zena', 'Hello World!.zml'.to_filename))
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
    art         = secure(Node) { nodes(:art) }
    collections = secure(Node) { nodes(:collections) }
    cleanWater  = secure(Node) { nodes(:cleanWater) }

    assert art.update_attributes(:title => 'status title', :v_status => Zena::Status::Pub)

    assert_equal 'Collections/status title', art.fullpath_as_title.join('/')

       # path                           base_node
    { ['(/projects list/Clean Water project/status title)', nil]          => nodes_id(:status),
      ['(/projects list/Clean Water project/status title)', collections]  => nodes_id(:status),
      ['(status title)', collections]                                     => nodes_id(:art),
      ['(status title)', cleanWater]                                      => nodes_id(:status),
    }.each do |k, v|
      assert_equal v, secure(Node) { Node.translate_pseudo_id(k[0],:id,k[1]) }, "'#{k[0]}' in '#{k[1] ? k[1].title : 'nil
      '}' should translate to '#{v}'"
    end
  end

  def test_unparse_assets
    login(:lion)
    @node = secure!(Node) { nodes(:status) }
    assert @node.update_attributes(:text => "Hello this is \"art\":#{nodes_zip(:art)}. !#{nodes_zip(:bird_jpg)}!")
    assert_equal "Hello this is \"art\":(../../../Collections/Art). !(../../a wiki with Zena/bird)!", @node.unparse_assets(@node.text, self, 'text')
  end

  def test_parse_assets
    login(:lion)
    @node = secure!(Node) { nodes(:status) }
    assert @node.update_attributes(:text => "Hello this is \"art\":(../../../Collections/Art).")
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
          assert_match %r{rel\[.#{k.gsub(/_.+/,'')}.\]\.try}, VirtualClass['Page'].safe_method_type([k])[:method]
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
        assert_transforms "Hi, this is just a simple \"test\":49 or \"\":43_life.rss. OK ?\n\n!24_pv!",
                          "Hi, this is just a simple \"test\"::w or \"\"::w++_life.rss. OK ?\n\n!:lake_pv!"
      end

      should 'parse pseudo ids with offset in gallery' do
        assert_transforms "Hi ![30,23]! ![]!",
                          "Hi ![30,:lake+]! ![]!"
      end

      should 'parse pseudo ids in doc_list' do
        assert_transforms "Hi !{30,23}! !{}!",
                          "Hi !{:bird,:lake+}! !{}!"

      end

      should 'parse pseudo ids in links' do
        assert_transforms "Hi !30!:21 !30!:37 !30/nice bird!:21 !30_pv/hello ladies!:21",
                          "Hi !30!::clean+ !:bird!::clean !:bird/nice bird!:21 !30_pv/hello ladies!:21"
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

      should 'transform parent_id to parent_zip' do
        assert_transforms Hash['parent_zip' => 'lake+'],
                          Hash['parent_id'  => 'lake+']
        # nodes_id(:lake_jpg)
      end

      should 'transform link ids to zip' do
        assert_transforms Hash['tag_zips' => %w{33 news}],
                          Hash['tag_ids' => '33,news']
        # [nodes_id(:art), nodes_id(:news)]
      end

      should 'parse dates and ids in rel' do
        # this should be 14:58 when #255 is fixed (tz support).
        assert_transforms Hash['link' => {'hot' => {'other_zip' => '22', 'date' => Time.gm(2009,7,15,16,58)}}],
                          Hash['link' => {'hot' => {'other_id'  => '22', 'date' => '2009-7-15 16:58' }}]
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