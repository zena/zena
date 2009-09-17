require 'test_helper'

class NodeTest < Zena::Unit::TestCase

  NEW_DEFAULT = {
    :name       => 'hello',
    :rgroup_id  => Zena::FoxyParser::id('zena', 'public'),
    :wgroup_id  => Zena::FoxyParser::id('zena', 'workers'),
    :pgroup_id  => Zena::FoxyParser::id('zena', 'managers'),
    :parent_id  => Zena::FoxyParser::id('zena', 'cleanWater'),
  }.freeze

  def test_find_by_path
    Node.connection.execute "UPDATE nodes SET fullpath = NULL, basepath = NULL WHERE id = #{nodes_id(:wiki)}"
    login(:ant)
    node = nodes(:wiki)
    assert_nil node[:fullpath]
    node = secure!(Node) { Node.find_by_path('projects/wiki') }
    assert_equal 'projects/wiki', node.fullpath
    node = secure!(Node) { Node.find_by_path('projects/wiki') }
    assert_equal 'projects/wiki', node[:fullpath]
  end

  def test_match_query
    query = Node.match_query('smala')
    assert_equal "nodes.name LIKE 'smala%'", query[:conditions]
    query = Node.match_query('.', :node => nodes(:wiki))
    assert_equal ["parent_id = ?", nodes_id(:wiki)], query[:conditions]
  end

  def test_transform_attributes_zazen_shortcut_v_text
    login(:tiger)
    [
      ["Hi, this is just a simple \"test\"::w or \"\"::w+_life.rss. OK ?\n\n!:lake+_pv!",
       "Hi, this is just a simple \"test\":25 or \"\":29_life.rss. OK ?\n\n!24_pv!"],

      ["Hi ![30,:lake+]! ![]!",
       "Hi ![30,24]! ![]!"],

      ["Hi !{:bird,:lake+}! !{}!",
       "Hi !{30,24}! !{}!"],

      ["Hi !30!::clean !:bird!::clean !:bird/nice bird!:21 !30_pv/hello ladies!:21",
       "Hi !30!:21 !30!:21 !30/nice bird!:21 !30_pv/hello ladies!:21"],

      ["Hi, this is normal "":1/ just a\n\n* asf\n* asdf ![23,33]!",
       "Hi, this is normal "":1/ just a\n\n* asf\n* asdf ![23,33]!"],
    ].each do |src,res|
      assert_equal res, secure(Node) { Node.transform_attributes( 'v_text' => src )['v_text'] }
    end
  end

  def test_transform_attributes
    login(:tiger)
    visitor[:time_zone] = "Europe/Zurich"
    [
      [{'parent_id' => 'lake+'},
       {'parent_id' => nodes_id(:lake_jpg)}],

      [{'d_super_id' => 'lake',           'd_other_id' => '11'},
       {'d_super_id' => nodes_zip(:lake), 'd_other_id' => 11}],

      [{'tag_ids' => "33,news"},
       {'tag_ids' => [nodes_id(:art), nodes_id(:news)]}],

      [{'parent_id' => '999', 'tag_ids' => "999,34,art"},
       {'parent_id' => '999', 'tag_ids' => [nodes_id(:news),nodes_id(:art)]}],

      [{'link' => {'hot' => {'other_id' => '22', 'date' => '2009-7-15 16:58' }}},
       {'link' => {'hot' => {'other_id' => nodes_id(:status), 'date' => Time.gm(2009,7,15,16,58)}}}], # this should be 14:58 when #255 is fixed (tz support).
    ].each do |src,res|
      assert_equal res, secure(Node) { Node.transform_attributes( src ) }
    end
  end

  def test_get_fullpath
    Node.connection.execute "UPDATE nodes SET fullpath = NULL, basepath = NULL WHERE id IN (#{nodes_id(:lake)},#{nodes_id(:cleanWater)})"
    login(:ant)
    node = secure!(Node) { nodes(:lake)  }
    parent = node.parent
    assert_nil parent[:fullpath]
    assert_nil node[:fullpath]
    assert_equal 'projects/cleanWater/lakeAddress', node.fullpath
    node.reload
    assert_equal 'projects/cleanWater/lakeAddress', node[:fullpath]
    parent.reload
    assert_equal 'projects/cleanWater', parent[:fullpath]
  end

  def test_get_fullpath_rebuild
    login(:ant)
    node = secure!(Node) { nodes(:lake)  }
    assert_equal 'projects/cleanWater/lakeAddress', node.fullpath
    Node.connection.execute "UPDATE nodes SET parent_id = #{nodes_id(:collections)} WHERE id = #{node[:id]}"
    node.reload
    assert_equal 'projects/cleanWater/lakeAddress', node.fullpath
    assert_equal 'collections/lakeAddress', node.fullpath(true)
  end

  def test_get_fullpath_after_private
    Node.connection.execute "UPDATE nodes SET parent_id = #{nodes_id(:ant)} WHERE id = #{nodes_id(:status)}" # put 'status' page inside private 'ant' page
    node = nil
    login(:tiger)
    assert_nothing_raised { node = secure!(Node) { nodes(:status) } }
    assert_kind_of Node, node
    assert_raises (ActiveRecord::RecordNotFound) { node = secure!(Node) { Node.find_by_path('people/ant') } }
    assert_nothing_raised { node = secure!(Node) { Node.find_by_path('people/ant/status')}}
  end

  def test_fullpath_updated_on_parent_rename
    login(:tiger)
    node = secure!(Node) { nodes(:tiger) }
    assert_equal 'people/tiger', node.fullpath
    node = secure!(Node) { nodes(:tiger) }
    assert_equal 'people/tiger', node[:fullpath] # make sure fullpath is cached

    node = secure!(Node) { nodes(:people) }
    assert node.update_attributes(:v_title => 'nice people')
    assert node.publish
    assert_equal 'nicePeople', node.name # sync name
    node = secure!(Node) { nodes(:tiger) }
    assert_nil node[:fullpath] # cache empty
    assert_equal 'nicePeople/tiger', node.fullpath
  end

  def test_rootpath
    login(:ant)
    node = secure!(Node) { nodes(:status) }
    assert_equal 'zena/projects/cleanWater/status', node.rootpath
    node = secure!(Node) { nodes(:zena) }
    assert_equal 'zena', node.rootpath
  end

  def test_basepath
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    assert_equal 'projects/cleanWater', node.basepath
    node = secure!(Node) { nodes(:projects) }
    assert_equal '', node.basepath
    node = secure!(Node) { nodes(:proposition) }
    assert_equal '', node.basepath
  end

  def test_ancestors
    Node.connection.execute "UPDATE nodes SET parent_id = #{nodes_id(:proposition)} WHERE id = #{nodes_id(:bird_jpg)}"
    login(:ant)
    node = secure!(Node) { nodes(:status) }
    assert_equal ['zena', 'projects', 'cleanWater'], node.ancestors.map { |a| a[:name] }
    node = secure!(Node) { nodes(:zena) }
    assert_equal [], node.ancestors
    node = secure!(Node) { nodes(:bird_jpg) }
    prop = secure!(Node) { nodes(:proposition)}
    assert_kind_of Node, prop
    assert prop.can_read?
    assert_equal ['zena', 'projects', 'proposition'], node.ancestors.map { |a| a[:name] }
  end

  def test_ancestors_infinit_loop
    Node.connection.execute "UPDATE nodes SET parent_id = #{nodes_id(:status)} WHERE id = #{nodes_id(:cleanWater)}"
    login(:ant)
    node = secure!(Node) { nodes(:lake_jpg) }
    assert_raise(Zena::InvalidRecord) { node.ancestors }
  end

  def test_ancestor_in_hidden_project
    login(:ant)
    node = secure!(Node) { nodes(:proposition) }
    assert_kind_of Node, node
    assert_equal ['zena', 'projects'], node.ancestors.map { |a| a[:name] } # ant can view 'proposition' but not the project proposition is in
  end

  def test_create_simplest
    login(:ant)
    test_page = secure!(Node) { Node.create(:name=>"yoba", :parent_id => nodes_id(:cleanWater), :inherit=>1 ) }
    assert ! test_page.new_record? , "Not a new record"
    assert_equal nodes_id(:cleanWater), test_page.parent[:id]
  end

  def test_cannot_update_v_status
    login(:ant)
    test_page = secure!(Node) { nodes(:status) }
    assert_equal 2, test_page.version.number
    assert test_page.update_attributes( :v_status => Zena::Status[:pub], :v_title => "New funky title")
    assert_equal 3, test_page.version.number
    assert_equal Zena::Status[:red], test_page.version.status
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

  def test_page_new_without_name
    login(:tiger)
    node = secure!(Node) { Node.new(:parent_id=>nodes_id(:cleanWater)) }
    assert ! node.save, 'Save fails'
    assert_equal 'can\'t be blank', node.errors[:name]
  end

  def test_new_set_section_id
    login(:tiger)
    node = secure!(Page) { Page.create(:parent_id=>nodes_id(:people), :name=>'SuperPage')}
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
    assert_equal 'invalid reference', node.errors[:parent_id]

    node = secure!(Node) { nodes(:status)  }
    node[:parent_id] = nodes_id(:projects) # parent ok
    assert node.save , "Save succeeds"
  end

  def test_page_update_without_name
    login(:tiger)
    node = secure!(Node) { nodes(:status)  }
    node[:name] = nil
    assert node.save, 'Save succeeds'
    assert_equal 'statusTitle', node[:name]
    node = secure!(Node) { nodes(:status)  }
    node[:name] = nil
    node.version.title = ""
    assert !node.save, 'Save fails'
    assert_equal 'can\'t be blank', node.errors[:name]
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

  def test_before_destroy
    login(:tiger)
    node = secure!(Node) { nodes(:projects)  }
    assert !node.destroy, "Cannot destroy"
    assert_equal 'contains subpages or data', node.errors[:base]
    node = secure!(Node) { nodes(:bananas)  }
    assert node.destroy, "Can destroy"
  end

  def test_cannot_destroy_has_private
    login(:tiger)
    node = secure!(Node) { nodes(:lion)  }
    assert_nil node.find(:all, 'pages'), "No subpages"
    assert !node.destroy, "Cannot destroy"
    assert_equal 'contains subpages or data', node.errors[:base]
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
    login(:ant)
    assert_equal nodes_id(:people), secure!(Node) { nodes(:ant) }.section[:id]
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
    login(:ant)
    node = secure!(Node) { nodes(:ant) }
    assert_equal nodes_id(:people), node.section[:id]
    node = secure!(Node) { nodes(:people) }
    assert_equal nodes_id(:people), node.section[:id]
    assert_equal nodes_id(:zena), node.real_section[:id]
    assert_equal nodes_id(:zena), node.real_section.real_section[:id]
  end

  def test_new_child
    login(:ant)
    node = secure!(Node) { nodes(:cleanWater)  }
    child = node.new_child( :name => 'status', :class => Page )
    assert ! child.save , "Save fails"
    assert child.errors[:name].any?

    child = node.new_child( :name => 'new_name', :class => Page )
    assert child.save , "Save succeeds"
    assert_equal Zena::Status[:red],  child.version.status
    assert_equal child[:user_id], users_id(:ant)
    assert_equal node[:pgroup_id], child[:pgroup_id]
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
    login(:ant)
    node = secure!(Node) { nodes(:status) }
    assert_equal node.user.site_participation[:contact_id], node.author[:id]
    assert_equal 'Solenopsis Invicta', node.author.fullname
    login(:anon)
    node = secure!(Node) { nodes(:status) }
    assert_nil node.author
  end

  def test_ext
    node = nodes(:status)
    node[:name] = 'bob. and bob.jpg'
    assert_equal 'jpg', node.ext
    node[:name] = 'no ext'
    assert_equal '', node.ext
    node[:name] = ''
    assert_equal '', node.ext
    node[:name] = nil
    assert_equal '', node.ext
  end

  def test_set_name_with_title
    login(:tiger)
    node = secure!(Node) { Node.create(NEW_DEFAULT.stringify_keys.merge('name' => '', 'v_title' => 'small bed')) }
    assert_kind_of Node, node
    assert !node.new_record?
    assert_equal 'smallBed', node.name
  end

  def test_set_name
    node = nodes(:wiki)
    node.name = " J'aime l'aïl en août ! "
    assert_equal 'JAimeLAilEnAout', node.name
    assert_equal 'JAimeLAilEnAout', node[:name]
    node.name = "LIEUX"
    assert_equal 'LIEUX', node.name
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
    login(:ant)
    node = secure!(Node) { nodes(:ant) }
    assert_equal nodes_id(:people), node[:section_id]
    node[:parent_id] = nodes_id(:collections)
    assert node.save
    assert_equal nodes_id(:zena), node[:section_id]
    assert_equal nodes_id(:zena), nodes(:myLife)[:section_id]
  end

  def test_sync_project_for_node
    login(:ant)
    node = secure!(Node) { nodes(:ant) }
    assert_equal nodes_id(:people), node[:section_id]
    assert_equal nodes_id(:zena  ), node[:project_id]
    node[:parent_id] = nodes_id(:cleanWater)
    assert node.save
    assert_equal nodes_id(:cleanWater), node[:project_id]
    assert_equal nodes_id(:cleanWater), nodes(:myLife)[:project_id]
    assert_equal nodes_id(:zena      ), node[:section_id]
    assert_equal nodes_id(:zena      ), nodes(:myLife)[:section_id]
  end

  def test_sync_project_for_section
    login(:tiger)
    node = secure!(Node) { nodes(:people) }
    assert_equal nodes_id(:people), node.get_section_id
    assert_equal nodes_id(:zena  ), node[:project_id]
    node[:parent_id] = nodes_id(:cleanWater)
    assert node.save
    assert_equal nodes_id(:cleanWater), node[:project_id]
    assert_equal nodes_id(:cleanWater), nodes(:myLife)[:project_id]
    assert_equal nodes_id(:people), node.get_section_id
    assert_equal nodes_id(:people), nodes(:myLife)[:section_id]
  end

  def test_after_unpublish
    Version.connection.execute "UPDATE versions SET user_id=#{users_id(:tiger)} WHERE node_id IN (#{[:wiki,:bird_jpg,:flower_jpg].map{|k| nodes_id(k)}.join(',')})"
    Node.connection.execute "UPDATE nodes SET user_id=#{users_id(:tiger)} WHERE id IN (#{[:wiki,:bird_jpg,:flower_jpg].map{|k| nodes_id(k)}.join(',')})"
    login(:tiger)
    wiki   = secure!(Node) { nodes(:wiki)       }
    bird   = secure!(Node) { nodes(:bird_jpg)   }
    flower = secure!(Node) { nodes(:flower_jpg) }
    assert_equal Zena::Status[:pub], wiki.version.status
    assert_equal Zena::Status[:pub], bird.version.status
    assert_equal Zena::Status[:pub], flower.version.status
    assert wiki.unpublish, 'Can unpublish publication'
    assert_equal 10, wiki.version.status
    assert_equal 10, wiki.max_status
    bird = secure!(Node) { nodes(:bird_jpg) }
    flower = secure!(Node) { nodes(:flower_jpg) }
    assert_equal 10, bird.version.status
    assert_equal 10, flower.version.status
    assert wiki.publish, 'Can publish'
    bird = secure!(Node) { nodes(:bird_jpg) }
    flower = secure!(Node) { nodes(:flower_jpg) }
    assert_equal Zena::Status[:pub], bird.version.status
    assert_equal Zena::Status[:pub], bird.max_status
    assert_equal Zena::Status[:pub], flower.version.status
  end

  def test_after_propose
    Version.connection.execute "UPDATE versions SET status = #{Zena::Status[:red]}, user_id=#{users_id(:tiger)} WHERE node_id IN (#{[:wiki,:bird_jpg,:flower_jpg].map{|k| nodes_id(k)}.join(',')})"
    Node.connection.execute "UPDATE nodes SET max_status = #{Zena::Status[:red]}, user_id=#{users_id(:tiger)} WHERE id IN (#{[:wiki,:bird_jpg,:flower_jpg].map{|k| nodes_id(k)}.join(',')})"
    login(:tiger)
    wiki = secure!(Node) { nodes(:wiki) }
    bird = secure!(Node) { nodes(:bird_jpg) }
    flower = secure!(Node) { nodes(:flower_jpg) }
    assert_equal Zena::Status[:red], wiki.version.status
    assert_equal Zena::Status[:red], bird.version.status
    assert_equal Zena::Status[:red], flower.version.status
    assert wiki.propose, 'Can propose for publication'
    assert_equal Zena::Status[:prop], wiki.version.status
    bird = secure!(Node) { nodes(:bird_jpg) }
    flower = secure!(Node) { nodes(:flower_jpg) }
    assert_equal Zena::Status[:prop_with], bird.version.status
    assert_equal Zena::Status[:prop_with], flower.version.status
    assert wiki.publish, 'Can publish'
    bird = secure!(Node) { nodes(:bird_jpg) }
    flower = secure!(Node) { nodes(:flower_jpg) }
    assert_equal Zena::Status[:pub], bird.version.status
    assert_equal Zena::Status[:pub], bird.max_status
    assert_equal Zena::Status[:pub], flower.version.status
  end

  def test_after_refuse
    Version.connection.execute "UPDATE versions SET status = #{Zena::Status[:red]}, user_id=#{users_id(:tiger)} WHERE node_id IN (#{[:wiki,:bird_jpg,:flower_jpg].map{|k| nodes_id(k)}.join(',')})"
    Node.connection.execute "UPDATE nodes SET max_status = #{Zena::Status[:red]}, user_id=#{users_id(:tiger)} WHERE id IN (#{[:wiki,:bird_jpg,:flower_jpg].map{|k| nodes_id(k)}.join(',')})"
    login(:tiger)
    wiki = secure!(Node) { nodes(:wiki) }
    assert wiki.propose, 'Can propose for publication'
    assert_equal Zena::Status[:prop], wiki.version.status
    bird = secure!(Node) { nodes(:bird_jpg) }
    flower = secure!(Node) { nodes(:flower_jpg) }
    assert_equal Zena::Status[:prop_with], bird.version.status
    assert_equal Zena::Status[:prop_with], flower.version.status
    assert wiki.refuse, 'Can refuse'
    bird = secure!(Node) { nodes(:bird_jpg) }
    flower = secure!(Node) { nodes(:flower_jpg) }
    assert_equal Zena::Status[:red], bird.version.status
    assert_equal Zena::Status[:red], bird.version.status
    assert_equal Zena::Status[:red], bird.max_status
    assert_equal Zena::Status[:red], flower.version.status
  end

  def test_after_publish
    Version.connection.execute "UPDATE versions SET status = #{Zena::Status[:red]}, user_id=#{users_id(:tiger)} WHERE node_id IN (#{[:wiki,:bird_jpg,:flower_jpg].map{|k| nodes_id(k)}.join(',')})"
    Node.connection.execute "UPDATE nodes SET max_status = #{Zena::Status[:red]}, user_id=#{users_id(:tiger)} WHERE id IN (#{[:wiki,:bird_jpg,:flower_jpg].map{|k| nodes_id(k)}.join(',')})"
    login(:tiger)
    wiki = secure!(Node) { nodes(:wiki) }
    assert wiki.publish, 'Can publish'
    assert_equal Zena::Status[:pub], wiki.version.status
    bird = secure!(Node) { nodes(:bird_jpg) }
    flower = secure!(Node) { nodes(:flower_jpg) }
    assert_equal Zena::Status[:pub], bird.version.status
    assert_equal Zena::Status[:pub], bird.max_status
    assert_equal Zena::Status[:pub], flower.version.status
  end

  def test_all_children
    login(:tiger)
    assert_raise(ActiveRecord::RecordNotFound) { secure!(Node) { nodes(:ant) }  }
    nodes  = secure!(Node) { nodes(:people).send(:all_children) }
    people = secure!(Node) { nodes(:people) }
    assert_equal 4, nodes.size
    assert_equal 3, people.find(:all, 'children').size
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
    assert_equal 'art', tags[0].name
    assert_equal 'news', tags[1].name
    @node.rel['set_tag'].other_ids = [nodes_id(:art)]
    @node.save
    tags = @node.find(:all, 'set_tags')
    assert_equal 1, tags.size
    assert_equal 'art', tags[0].name
  end

  def test_tag_update
    login(:lion)
    node = secure!(Node) { nodes(:art) }
    assert node.update_attributes('tagged_ids' => [nodes_id(:status), nodes_id(:people)])
    assert_equal 2, node.find(:all, 'tagged').size
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
      assert node.update_attributes(:v_title=>'new title'), "Can change attributes"
      # sweep only kpath NPP
      i = 3
      assert_equal "content 3", Cache.with(visitor.id, visitor.group_ids, 'NP', 'pages')  { "content #{i}" }
      assert_equal "content 1", Cache.with(visitor.id, visitor.group_ids, 'NN', 'notes')  { "content #{i}" }

      # do something on a note
      node = secure!(Node) { nodes(:proposition) }
      assert_equal 'NNP', node.vclass.kpath
      assert node.update_attributes(:name => 'popo' ), "Can change attributes"
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
    assert_equal Zena::Status[:pub], node.version.status
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
    node.update_attributes( :v_title=>'test' )
    discussion = node.discussion
    assert_kind_of Discussion, discussion
    assert discussion.inside?
  end

  def test_inside_discussion
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    node.update_attributes( :v_title=>'new status' )
    assert_equal Zena::Status[:red], node.version.status
    discussion = node.discussion
    assert_equal discussions_id(:inside_discussion_on_status), discussion[:id]
  end

  def test_auto_create_discussion
    login(:tiger)
    post   = secure!(Node) { Node.create_node(:v_status => Zena::Status[:pub], :v_title => 'a new post', :class => 'Post', :parent_id => nodes_zip(:cleanWater)) }
    letter = secure!(Node) { Node.create_node(:v_status => Zena::Status[:pub], :v_title => 'a letter', :class => 'Letter', :parent_id => nodes_zip(:cleanWater)) }
    assert !post.new_record?, "Not a new record"
    assert !letter.new_record?, "Not a new record"
    assert_equal Zena::Status[:pub], post.version.status, "Published"
    assert_equal Zena::Status[:pub], letter.version.status, "Published"
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
    letter = secure!(Node) { Node.create_node(:v_status => Zena::Status[:pub], :v_title => 'a letter', :class => 'Letter', :parent_id => nodes_zip(:cleanWater)) }
    assert !letter.new_record?, "Not a new record"
    assert_equal Zena::Status[:pub], letter.version.status, "Published"
    login(:anon)
    letter = secure!(Node) { Node.find(letter.id) }
    assert !letter.can_auto_create_discussion?
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
    node = secure!(Node) { Node.create(:parent_id=>nodes_id(:ocean), :rgroup_id=>groups_id(:aqua), :wgroup_id=>groups_id(:masters), :pgroup_id=>groups_id(:masters), :name=>"fish") }
    assert !node.new_record?, "Not a new record"
    assert_equal sites_id(:ocean), node[:site_id]
  end

  def test_other_site_id_fool_id
    login(:whale)
    node = secure!(Node) { Node.create(:parent_id=>nodes_id(:ocean), :rgroup_id=>groups_id(:aqua), :wgroup_id=>groups_id(:masters), :pgroup_id=>groups_id(:masters), :name=>"fish", :site_id=>sites_id(:zena)) }
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

  def test_zip
    next_zip = Node.connection.execute("SELECT zip FROM zips WHERE site_id = #{sites_id(:zena)}").fetch_row[0].to_i
    login(:tiger)
    node = secure!(Node) { Node.create(:parent_id=>nodes_id(:zena), :name=>"fly")}
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
    node = secure!(Node) { Node.create_node(:parent_id => nodes_zip(:secret), :name => 'funny') }
    assert_equal nodes_id(:secret), node[:parent_id]
    assert node.new_record?, "Not saved"
    assert_equal 'invalid reference', node.errors[:parent_id]
  end

  def test_create_node_with__parent_id
    login(:ant)
    node = secure!(Node) { Node.create_node(:_parent_id => nodes_id(:secret), :name => 'funny') }
    assert_equal nodes_id(:secret), node[:parent_id]
    assert node.new_record?, "Not saved"
    assert_equal 'invalid reference', node.errors[:parent_id]
  end

  def test_create_node_ok
    login(:ant)
    node = secure!(Node) { Node.create_node('parent_id' => nodes_zip(:myLife), 'name' => 'funny') }
    assert_equal nodes_id(:myLife), node[:parent_id]
    assert_equal 'funny', node[:name]
    assert !node.new_record?, "Saved"
  end

  def test_create_or_update_node_create
    login(:ant)
    node = secure!(Node) { Node.create_or_update_node('parent_id' => nodes_zip(:myLife), 'name' => 'funny') }
    assert_equal nodes_id(:myLife), node[:parent_id]
    assert_equal 'funny', node[:name]
    assert !node.new_record?, "Saved"
  end

  def test_create_or_update_node_update
    login(:ant)
    node = secure!(Node) { Node.create_or_update_node('parent_id' => nodes_zip(:cleanWater), 'name' => 'status', 'v_title'=>"It's all broken") }
    assert_equal nodes_id(:cleanWater), node[:parent_id]
    assert_equal nodes_id(:status), node[:id]
    node = secure!(Node) { nodes(:status) }
    assert_equal 'status', node[:name]
    assert_equal "It's all broken", node.version.title
  end

  def test_create_with_klass
    login(:tiger)
    node = secure!(Node) { Node.create_node('parent_id' => nodes_zip(:projects), 'name' => 'funny', 'klass' => 'TextDocument', 'c_content_type' => 'application/x-javascript') }
    assert_kind_of TextDocument, node
    assert_equal nodes_id(:projects), node[:parent_id]
    assert_equal 'funny', node[:name]
    assert !node.new_record?, "Saved"
  end

  def test_get_class
    assert_equal Node, Node.get_class('node')
    assert_equal Node, Node.get_class('nodes')
    assert_equal Node, Node.get_class('Node')
    assert_equal virtual_classes(:Letter), Node.get_class('Letter')
    assert_equal TextDocument, Node.get_class('TextDocument')
  end

  def test_get_class_from_kpath
    assert_equal Node, Node.get_class_from_kpath('N')
    assert_equal Page, Node.get_class_from_kpath('NP')
    assert_equal Image, Node.get_class_from_kpath('NDI')
    assert_equal virtual_classes(:Post), Node.get_class_from_kpath('NNP')
    assert_equal virtual_classes(:Letter), Node.get_class_from_kpath('NNL')
    assert_equal TextDocument, Node.get_class_from_kpath('NDT')
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
    parent = secure!(Project) { Project.create(:name => 'import', :parent_id => nodes_id(:zena)) }
    assert !parent.new_record?, "Not a new record"
    nodes = secure!(Node) { Node.create_nodes_from_folder(:archive => uploaded_archive('simple.zml.gz'), :parent_id => parent[:id] )}.values
    assert_equal 1, nodes.size
    simple = nodes[0]
    assert_kind_of Note, simple
    assert_equal virtual_classes(:Post), simple.vclass
    assert !simple.new_record?
  end

  def test_create_nodes_from_folder_with_defaults
    login(:tiger)
    parent = secure!(Project) { Project.create(:name => 'import', :parent_id => nodes_id(:zena), :rgroup_id => groups_id(:managers), :wgroup_id => groups_id(:managers)) }
    assert !parent.new_record?, "Not a new record"
    result = secure!(Node) { Node.create_nodes_from_folder(:folder => File.join(RAILS_ROOT, 'test', 'fixtures', 'import'), :parent_id => parent[:id] )}.values
    assert_equal 4, result.size

    children = parent.find(:all, 'children order by name ASC')
    assert_equal 2, children.size
    assert_equal 'photos', children[0].name
    assert_equal groups_id(:managers), children[0].rgroup_id
    assert_equal 'simple', children[1].name
    assert_equal groups_id(:managers), children[1].rgroup_id

    # we use children[1] as parent just to use any empty node
    result = secure!(Node) { Node.create_nodes_from_folder(:folder => File.join(RAILS_ROOT, 'test', 'fixtures', 'import'), :parent_id => children[1][:id], :defaults => { :rgroup_id => groups_id(:public) } )}.values
    assert_equal 4, result.size

    children = children[1].find(:all, 'children order by name ASC')
    assert_equal 2, children.size
    assert_equal 'photos', children[0].name
    assert_equal groups_id(:public), children[0].rgroup_id
  end

  def test_create_nodes_from_folder_with_publish
    login(:tiger)
    nodes = secure!(Node) { Node.create_nodes_from_folder(:folder => File.join(RAILS_ROOT, 'test', 'fixtures', 'import'), :parent_id => nodes_id(:zena) )}.values
    assert_equal Zena::Status[:red], nodes[0].version.status

    nodes = secure!(Node) { Node.create_nodes_from_folder(:folder => File.join(RAILS_ROOT, 'test', 'fixtures', 'import'), :parent_id => nodes_id(:cleanWater), :defaults => { :v_status => Zena::Status[:pub] }) }.values
    assert_equal Zena::Status[:pub], nodes[0].version.status
  end

  def test_create_nodes_from_archive
    login(:tiger)
    res = secure!(Node) { Node.create_nodes_from_folder(:archive => uploaded_archive('import.tgz'), :parent_id => nodes_id(:zena)) }.values
    photos = secure!(Section) { Section.find_by_name('photos') }
    assert_kind_of Section, photos
    bird = secure!(Node) { Node.find_by_parent_id_and_name(photos[:id], 'bird') }
    assert_kind_of Image, bird
    assert_equal 56183, bird.version.content.size
    assert_equal 'Lucy in the sky', bird.version.title
    visitor.lang = 'fr'
    bird = secure!(Node) { Node.find_by_parent_id_and_name(photos[:id], 'bird') }
    assert_equal 'Le septième ciel', bird.version.title
    assert_equal 1, bird[:inherit]
    assert_equal groups_id(:public), bird[:rgroup_id]
    assert_equal groups_id(:workers), bird[:wgroup_id]
    assert_equal groups_id(:managers), bird[:pgroup_id]

    simple = secure!(Node) { Node.find_by_parent_id_and_name(nodes_id(:zena), 'simple') }
    assert_equal 0, simple[:inherit]
    assert_equal groups_id(:managers), simple[:rgroup_id]
    assert_equal groups_id(:managers), simple[:wgroup_id]
    assert_equal groups_id(:managers), simple[:pgroup_id]
  end

  def test_create_nodes_from_zip_archive
    login(:tiger)
    res = secure!(Node) { Node.create_nodes_from_folder(:archive => uploaded_zip('letter.zip'), :parent_id => nodes_id(:zena), :class => 'Letter') }.values
    res.sort!{|a,b| a.name <=> b.name}
    letter, bird = res[1], res[0]
    assert_kind_of Note, letter
    assert_equal 'Letter', letter.klass
  end

  def test_update_nodes_from_archive
    preserving_files('test.host/data') do
      bird = node = nil
      login(:tiger)
      node = secure!(Page) { Page.create(:parent_id => nodes_id(:status), :name=>'photos', :v_title => 'my photos', :v_text => '![]!') }
      assert !node.new_record?
      assert_nothing_raised { node = secure!(Node) { Node.find_by_path( 'projects/cleanWater/status/photos') } }
      assert_raise(ActiveRecord::RecordNotFound) { node = secure!(Node) { Node.find_by_path( 'projects/cleanWater/status/photos/bird') } }
      assert_equal 'photos', node.name
      assert_no_match %r{I took during my last vacations}, node.version.text
      v1_id = node.version.id
      secure!(Node) { Node.create_nodes_from_folder(:archive => uploaded_archive('import.tgz'), :parent_id => nodes_id(:status)) }.values
      assert_nothing_raised { node = secure!(Node) { Node.find_by_path( 'projects/cleanWater/status/photos') } }
      assert_nothing_raised { bird = secure!(Node) { Node.find_by_path( 'projects/cleanWater/status/photos/bird') } }
      assert_match %r{I took during my last vacations}, node.version.text
      assert_equal v1_id, node.version.id
      assert_kind_of Image, bird
    end
  end

  def test_to_yaml
    User.connection.execute "UPDATE users SET time_zone = 'Asia/Jakarta' WHERE id = #{users_id(:tiger)}"
    login(:tiger)
    status = secure!(Node) { nodes(:status) }
    assert status.update_attributes_with_transformation(:v_status => Zena::Status[:pub], :v_text => "This is a \"link\":#{nodes_zip(:projects)}.", :d_foo => "A picture: !#{nodes_zip(:bird_jpg)}!")
    yaml = status.to_yaml
    assert_match %r{v_text:\s+\"?This is a "link":\(\.\./\.\.\)\.}, yaml
    assert_match %r{d_foo:\s+\"?A picture: !\(\.\./\.\./wiki/bird\)!}, yaml
    assert_no_match %r{log_at}, yaml

    prop = secure!(Node) { nodes(:proposition) }
    assert prop.update_attributes_with_transformation(:v_status => Zena::Status[:pub], :v_text => "This is a \"link\":#{nodes_zip(:projects)}.", :d_foo => "A picture: !#{nodes_zip(:bird_jpg)}!", :log_at => "2008-10-20 14:53")
    assert_equal Time.gm(2008,10,20,7,53), prop.log_at
    yaml = prop.to_yaml
    assert_match %r{v_text:\s+\"?This is a "link":\(\.\./\.\.\)\.}, yaml
    assert_match %r{d_foo:\s+\"?A picture: !\(\.\./\.\./wiki/bird\)!}, yaml
    assert_match %r{log_at:\s+\"?2008-10-20 14:53:00\"?$}, yaml
  end

  def test_order_position
    login(:tiger)
    parent = secure!(Node) { nodes(:cleanWater) }
    children = parent.find(:all, 'children')
    assert_equal 8, children.size
    assert_equal 'bananas', children[0].name
    assert_equal 'crocodiles', children[1].name

    Node.connection.execute "UPDATE nodes SET position = -1.0 WHERE id = #{nodes_id(:water_pdf)}"
    Node.connection.execute "UPDATE nodes SET position = -0.5 WHERE id = #{nodes_id(:lake)}"
    children = parent.find(:all, 'children')
    assert_equal 8, children.size
    assert_equal 'water', children[0].name
    assert_equal 'lakeAddress', children[1].name
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

  def test_zafu_attribute
    assert_equal "bob.name", Node.zafu_attribute('bob', 'name')
    assert_equal "bob.version.text", Node.zafu_attribute('bob', 'v_text')
    assert_equal 'bob.version.dyn["super"]', Node.zafu_attribute('bob', 'd_super')
    assert_equal 'bob.c_public_read("truc")', Node.zafu_attribute('bob', 'c_truc')
  end

  def test_classes_for_form
    assert_equal [["Page", "Page"],
     ["  Project", "Project"],
     ["  Section", "Section"],
     ["    Skin", "Skin"]], Node.classes_for_form(:class=>'Page', :without=>'Document')
  end

  def test_change_to_classes_for_form
    assert_equal [["Page", "Page"],
     ["  Project", "Project"],
     ["  Section", "Section"],
     ["    Skin", "Skin"]], Project.classes_for_form(:class=>'Page', :without=>'Document')
  end

  def test_allowed_change_to_classes
    node_changes = Node.allowed_change_to_classes.reject{|k| k[/Dummy/]} # In case we are testing after Secure
    assert_equal ["Node","Note","Letter","Post","Page","Project","Section","Skin","Reference"], node_changes

    assert_equal node_changes, Page.allowed_change_to_classes.reject{|k| k[/Dummy/]}
    assert_equal node_changes, Project.allowed_change_to_classes.reject{|k| k[/Dummy/]}
    assert_equal node_changes, Note.allowed_change_to_classes.reject{|k| k[/Dummy/]}
    assert_equal node_changes, Reference.allowed_change_to_classes.reject{|k| k[/Dummy/]}

    assert_equal ["Document","TextDocument","Template"], Document.allowed_change_to_classes.reject{|k| k[/Dummy/]}

    assert_equal ["Image"], Image.allowed_change_to_classes.reject{|k| k[/Dummy/]}

    assert_equal ["Contact"], Contact.allowed_change_to_classes.reject{|k| k[/Dummy/]}
  end

  def test_match_one_node_only
    login(:tiger)
    match = secure!(Node) { Node.find(:all, Node.match_query('opening')) }
    assert_equal 1, match.size
    assert_equal nodes_id(:opening), match[0][:id]
  end

  def find_nodes_with_pagination_in_cleanWaterProject(page, per_page = 3, opts=nil)
    previous_page, collection, next_page = nil, nil, nil
    opts ||= {:conditions => ['project_id = ?', nodes_id(:cleanWater)], :order=>'name ASC'}
    collection = secure(Node) do
      previous_page, collection, next_page = Node.find_with_pagination(:all, opts.merge(:page=>page, :per_page=>per_page))
      collection
    end
    [previous_page, collection, next_page]
  end

  def test_find_with_pagination_page_1
    login(:tiger)
    previous_page, collection, next_page = find_nodes_with_pagination_in_cleanWaterProject(1,3)
    assert_nil previous_page
    assert_equal 2, next_page
    assert_equal 3, collection.size
    assert_equal [:bananas, :crocodiles, :lake_jpg].map{|s| nodes_id(s)}, collection.map{|r| r[:id]}
  end

  def test_find_with_pagination_page_2
    login(:tiger)
    previous_page, collection, next_page = find_nodes_with_pagination_in_cleanWaterProject(2,3)
    assert_equal 1, previous_page
    assert_equal 3, next_page
    assert_equal 3, collection.size
    assert_equal [:lake, :opening, :status].map{|s| nodes_id(s)}, collection.map{|r| r[:id]}
  end

  def test_find_with_pagination_page_3
    login(:tiger)
    previous_page, collection, next_page = find_nodes_with_pagination_in_cleanWaterProject(3,3)
    assert_equal 2, previous_page
    assert_nil next_page
    assert_equal 2, collection.size
    assert_equal [:track, :water_pdf].map{|s| nodes_id(s)}, collection.map{|r| r[:id]}
  end

  def test_find_with_pagination_page_4
    login(:tiger)
    previous_page, collection, next_page = find_nodes_with_pagination_in_cleanWaterProject(4,3)
    assert_equal 3, previous_page
    assert_nil next_page
    assert_nil collection
  end

  def test_find_match_with_pagination
    login(:tiger)
    previous_page, match, next_page, count_all = secure!(Node) { Node.find_with_pagination(:all, Node.match_query('opening').merge(:page => 1, :per_page => 3)) }
    assert_equal 1, match.size
    assert_equal 1, count_all
    assert_nil previous_page
    assert_nil next_page
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

  def test_icon_by_relation
    login(:ant)
    node = secure!(Node) { nodes(:cleanWater) } # has an 'icon' relation
    icon = node.icon
    assert_kind_of Image, icon
    assert_equal nodes_id(:lake_jpg), icon[:id]
  end

  def test_icon_by_first_child
    login(:tiger)
    node = secure!(Node) { nodes(:wiki) } # has no 'icon' relation
    icon = node.icon
    assert_kind_of Image, icon
    assert_equal nodes_id(:bird_jpg), icon[:id] # first child
    # define flower as icon
    assert node.update_attributes(:icon_id => nodes_id(:flower_jpg))
    node = secure!(Node) { nodes(:wiki) } # reload
    icon = node.icon
    assert_kind_of Image, icon
    assert_equal nodes_id(:flower_jpg), icon[:id] # icon
  end

  def test_vkind_of
    login(:ant)
    node = secure!(Node) { nodes(:status) }
    assert node.vkind_of?("Page")
    node = secure!(Node) { nodes(:proposition) }
    assert node.vkind_of?("Post")
    node = secure!(Node) { nodes(:status) }
    assert !node.vkind_of?("Document")
  end

  def test_native_class_values
    assert Page.native_classes.values.include?(Project)
    assert !Project.native_classes.values.include?(Page)
  end

  def test_position_on_create
    login(:lion)
    node = secure!(Page) { Page.create(:name=>"yoba", :parent_id => nodes_id(:cleanWater), :inherit=>1 ) }
    assert !node.new_record?
    assert_equal 0.0, node.position
    assert node.update_attributes(:position => 5.0)
    assert_equal 5.0, node.position
    node = secure!(Page) { Page.find_by_id(node.id) } # reload
    assert_equal 5.0, node.position
    node = secure!(Page) { Page.create(:name=>"babo", :parent_id => nodes_id(:cleanWater), :inherit=>1 ) }
    assert !node.new_record?
    assert_equal 6.0, node.position

    # position has different scopes depending on first two letters of kpath: 'ND', 'NN', 'NP', 'NR'
    doc = secure!(Document) { Document.create( :parent_id=>nodes_id(:cleanWater),
                                              :c_file  => uploaded_file('water.pdf', 'application/pdf', 'wat'), :v_title => "lazy waters.pdf") }
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

  def test_add_comment
    login(:lion)
    node = secure!(Node) { nodes(:lion) }
    assert node.can_comment?
    assert_nil node.comments

    node = secure!(Node) { nodes(:lion) } # reload
    assert node.update_attributes(:m_title => 'changed icon', :m_text => 'new icon is "flower"', :icon_id => nodes_id(:flower_jpg))

    node = secure!(Node) { nodes(:lion) } # reload
    comments = node.comments
    assert_equal 1, comments.size
    comment = comments[0]
    assert_equal 'changed icon', comment[:title]
    assert_equal 'new icon is "flower"', comment[:text]
    assert_equal 'Panthera Leo Verneyi', comment.author_name
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
    new_attributes = node.replace_attributes_in_values(:foo => "id: [id], v_title: [v_title]")
    assert_equal "id: 22, v_title: status title", new_attributes[:foo]
  end

  def test_copy
    login(:lion)
    node = secure!(Node) { nodes(:status) }
    new_attributes = secure(Node) { Node.transform_attributes(:copy_id => nodes_zip(:bird_jpg), :icon_id => '[id]')}
    assert_equal Hash['icon_id', nodes_id(:bird_jpg)], new_attributes
    assert node.update_attributes_with_transformation(:copy_id => nodes_zip(:bird_jpg), :icon_id => '[id]')
    assert_equal nodes_id(:bird_jpg), node.find(:first, 'icon')[:id]
  end

  def test_export
    without_files('/test.host/tmp') do
      login(:tiger)
      export_folder = File.join(SITES_ROOT, 'test.host', 'tmp')
      FileUtils::mkpath(export_folder)
      # Add a page and a text document into 'wiki'
      assert secure!(Node) { Node.create(:v_title=>"Hello World!", :v_text => "Bonjour", :parent_id => nodes_id(:wiki), :inherit=>1 ) }
      assert secure!(TextDocument) { TextDocument.create(:name=>"yoba", :parent_id => nodes_id(:wiki), :v_text => "#header { color:red; }\n#footer { color:blue; }", :c_content_type => 'text/css') }
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
      assert secure!(Node) { Node.create(:v_title=>"Hello World!", :v_text => "Bonjour", :parent_id => nodes_id(:wiki), :inherit=>1 ) }
      assert secure!(TextDocument) { TextDocument.create(:name=>"yoba", :parent_id => nodes_id(:wiki), :v_text => "#header { color:red; }\n#footer { color:blue; }", :c_content_type => 'text/css') }
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
      'bird'                      => nodes_id(:bird_jpg),
      nodes_zip(:cleanWater).to_i => nodes_id(:cleanWater),
      nodes_zip(:status)          => nodes_id(:status),
      'statu'                     => nodes_id(:status),
    }.each do |k,v|
      assert_equal v, secure(Node) { Node.translate_pseudo_id(k) }, "'#{k}' should translate to '#{v}'"
    end
  end

  def test_translate_pseudo_id_path
    login(:lion)
    lion       = secure!(Node) { nodes(:lion) }
    people     = secure!(Node) { nodes(:people) }
    cleanWater = secure!(Node) { nodes(:cleanWater) }
    assert lion.update_attributes(:name => 'status')
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
    assert @node.update_attributes(:v_text => "Hello this is \"art\":#{nodes_zip(:art)}. !#{nodes_zip(:bird_jpg)}!")
    assert_equal "Hello this is \"art\":(../../../collections/art). !(../../wiki/bird)!", @node.unparse_assets(@node.version.text, self, 'v_text')
  end

  def test_parse_assets
    login(:lion)
    @node = secure!(Node) { nodes(:status) }
    assert @node.update_attributes(:v_text => "Hello this is \"art\":(../../../collections/art).")
    assert_equal "Hello this is \"art\":#{nodes_zip(:art)}.", @node.parse_assets(@node.version.text, self, 'v_text')
  end

  def test_safe_attribute
    login(:ant)
    node = secure(Node) { nodes(:ant) }
    ['v_puts', 'c_file', :raise, :blah, 'c_blah', 'c_system', 'system', 'v_system'].each do |k|
      assert ! node.safe_attribute?(k), "#{k} should not be readable"
    end

    ['v_status', 'id', :c_first_name, :c_name, 'parent_id', :m_text, :inherit, :v_title, 'd_blah', 'l_status', 'l_comment', 'hot_status', 'blah_comment', 'blah_zips', 'blah_id', 'blah_ids'].each do |k|
      assert node.safe_attribute?(k), "#{k} should be safe"
    end

    node = secure(Node) { nodes(:bird_jpg)}

    ['c_file'].each do |k|
      assert node.safe_attribute?(k), "#{k} should be safe"
    end
  end

  def test_sync_name_on_v_title_change_no_sync
    login(:tiger)
    # was not in sync
    node = secure!(Node) { nodes(:status) }
    assert node.update_attributes(:v_title => 'simply different')
    assert node.publish
    assert_equal 'status', node.name
    visitor.lang = 'fr'
    # not ref lang
    node = secure!(Node) { nodes(:people) }
    assert node.update_attributes(:v_title => 'nice people')
    assert node.publish
    assert_equal 'fr', node.version.lang
    assert_equal 'people', node.name
  end

  def test_sync_name_on_v_title_change
    login(:tiger)
    # was in sync, correct lang
    node = secure!(Node) { nodes(:people) }
    assert node.update_attributes(:v_title => 'nice people')
    assert_equal 'people', node.name
    assert_equal Zena::Status[:red], node.version.status
    assert node.publish
    assert_equal 'nicePeople', node.name
  end

  def test_sync_name_on_v_title_change_auto_pub_no_sync
    Site.connection.execute "UPDATE sites set auto_publish = 1, redit_time = 3600 WHERE id = #{sites_id(:zena)}"
    Version.connection.execute "UPDATE versions set updated_at = '#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}' WHERE node_id IN (#{nodes_id(:status)},#{nodes_id(:people)})"
    login(:tiger)
    # was not in sync
    node = secure!(Node) { nodes(:status) }
    assert node.update_attributes(:v_title => 'simply different')
    assert_equal 'status', node.name
    visitor.lang = 'fr'
    # not ref lang
    node = secure!(Node) { nodes(:people) }
    assert node.update_attributes(:v_title => 'nice people')
    assert_equal 'fr', node.version.lang
    assert_equal 'people', node.name
  end

  def test_sync_name_on_v_title_change_auto_pub
    Site.connection.execute "UPDATE sites set auto_publish = 1, redit_time = 3600 WHERE id = #{sites_id(:zena)}"
    Version.connection.execute "UPDATE versions set updated_at = '#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}' WHERE node_id IN (#{nodes_id(:people)})"
    login(:tiger)
    # was in sync, correct lang
    node = secure!(Node) { nodes(:people) }
    assert node.update_attributes(:v_title => 'nice people')
    assert_equal 'nicePeople', node.name
  end

  # FIXME: write test
  def test_assets
    assert true
    # sweep_cache (save) => remove asset folder
    # render math ?
  end

  def find_node_by_pseudo(string, base_node = nil)
    secure(Node) { Node.find_node_by_pseudo(string, base_node || @node) }
  end

  def test_should_parse_event_at_date
    I18n.locale = 'fr'
    visitor.time_zone = 'Asia/Jakarta'
    v = secure(Node) {Node.new('event_at' => '9-9-2009 15:17')}
    assert_equal Time.utc(2009,9,9,8,17), v.event_at
  end

  def test_should_parse_log_at_date
    I18n.locale = 'fr'
    visitor.time_zone = 'Asia/Jakarta'
    v = secure(Node) {Node.new('log_at' => '9-9-2009 15:17')}
    assert_equal Time.utc(2009,9,9,8,17), v.log_at
  end

  def test_parse_keys
    node = secure(Node) { nodes(:status) }
    assert_equal ["d_assigned", "v_text", "v_title", "d_problems", "d_archive"], node.parse_keys

    note = secure(Node) { nodes(:opening) }
    assert_equal ["v_text", "v_title"], note.parse_keys
  end
end