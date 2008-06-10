require File.dirname(__FILE__) + '/../test_helper'

class NodeTest < ZenaTestUnit

  NEW_DEFAULT = {
    :name       => 'hello',
    :rgroup_id  => ZenaTest::id('zena', 'public'),
    :wgroup_id  => ZenaTest::id('zena', 'workers'),
    :pgroup_id  => ZenaTest::id('zena', 'managers'),
    :parent_id  => ZenaTest::id('zena', 'cleanWater'),
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
      ["Hi, this is just a simple \"test\"::w or \"\"::w+_life.rss. OK ?\n\n!:lake+.pv!",
       "Hi, this is just a simple \"test\":25 or \"\":29_life.rss. OK ?\n\n!24.pv!"],
       
      ["Hi ![30,:lake+]! ![]!",
       "Hi ![30,24]! ![]!"],
       
      ["Hi !{:bird,:lake+}! !{}!",
       "Hi !{30,24}! !{}!"],

      ["Hi !30!::clean !:bird!::clean !:bird/nice bird!:21 !30.pv/hello ladies!:21",
       "Hi !30!:21 !30!:21 !30/nice bird!:21 !30.pv/hello ladies!:21"],
       
      ["Hi, this is normal "":1/ just a\n\n* asf\n* asdf ![23,33]!",
       "Hi, this is normal "":1/ just a\n\n* asf\n* asdf ![23,33]!"],
    ].each do |src,res|
      assert_equal res, secure(Node) { Node.transform_attributes( 'v_text' => src )['v_text'] }
    end
  end
  
  def test_transform_attributes_zazen_shortcut_ids
    login(:tiger)
    [
      [{'parent_id' => 'lake+'}, 
       {'parent_id' => nodes_id(:lake_jpg)}],
       
      [{'d_super_id' => 'lake',           'd_other_id' => '11'},
       {'d_super_id' => nodes_zip(:lake), 'd_other_id' => 11}],

      [{'tag_ids' => "33,news"},
       {'tag_ids' => [nodes_id(:art), nodes_id(:news)]}],
       
      [{'parent_id' => '999', 'tag_ids' => "999,34,art"},
       {'parent_id' => '999', 'tag_ids' => [nodes_id(:news),nodes_id(:art)]}],
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
    assert_equal 2, test_page.v_number
    test_page.update_attributes( :v_status => Zena::Status[:pub], :v_title => "New funky title")
    assert_equal 3, test_page.v_number
    assert_equal Zena::Status[:red], test_page.v_status
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
    assert node.errors[:parent_id] , "Errors on parent_id"
    assert_equal "invalid reference", node.errors[:parent_id]

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
    assert node.errors[:parent_id] , "Errors on parent_id"
    assert_equal "invalid reference", node.errors[:parent_id]
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
    assert_equal "can't be blank", node.errors[:name]
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
    assert node.errors[:parent_id] , "Errors on parent_id"
    node = secure!(Node) { nodes(:wiki) }
    node.parent_id = nodes_id(:wiki)
    assert ! node.save , "Save fails"
    assert node.errors[:parent_id] , "Errors on parent_id"
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
    assert node.errors[:parent_id] , "Errors on parent_id"
    assert_equal "invalid reference", node.errors[:parent_id]
    
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
    node.v_title = ""
    assert !node.save, 'Save fails'
    assert_equal node.errors[:name], "can't be blank"
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
    assert_equal node.errors[:base], 'contains subpages or data'
    node = secure!(Node) { nodes(:bananas)  }
    assert node.destroy, "Can destroy"
  end
  
  def test_cannot_destroy_has_private
    login(:tiger)
    node = secure!(Node) { nodes(:lion)  }
    assert_nil node.find(:all, 'pages'), "No subpages"
    assert !node.destroy, "Cannot destroy"
    assert_equal node.errors[:base], 'contains subpages or data'
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
    assert child.errors[:name] , "Errors on name"
  
    child = node.new_child( :name => 'new_name', :class => Page )
    assert child.save , "Save succeeds"
    assert_equal Zena::Status[:red],  child.v_status
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
 
  # TESTS FOR CHANGE_TO
  # def test_change_to_page_to_project
  #   login(:tiger)
  #   node = secure!(Node) { nodes(:people)  }
  #   id, parent_id, section_id = node[:id], node[:parent_id], node[:section_id]
  #   vers_count = Version.find(:all).size
  #   vers_id = node.v_id
  #   node = node.change_to(Section)
  #   assert_kind_of Section, node
  #   node = secure!(Section) { Section.find(nodes_id(:people)) }
  #   assert_kind_of Section, node
  #   assert_equal 'NPSP', node[:kpath]
  #   assert_equal id, node[:id]
  #   assert_equal parent_id, node[:parent_id]
  #   assert_equal node[:id], node[:section_id]
  #   assert_equal vers_count, Version.find(:all).size
  #   assert_equal vers_id, node.v_id
  #   assert_equal node[:id], nodes(:ant)[:section_id] # children inherit new section_id
  #   assert_equal node[:id], nodes(:myLife)[:section_id]
  # end
  # 
  # def test_change_project_to_page
  #   login(:tiger)
  #   node = secure!(Node) { nodes(:cleanWater)  }
  #   id, parent_id = node[:id], node[:parent_id]
  #   vers_count = Version.find(:all).size
  #   vers_id = node.v_id
  #   node = node.change_to(Page)
  #   assert_kind_of Page, node
  #   node = secure!(Page) { Page.find(nodes_id(:cleanWater)) }
  #   assert_kind_of Page, node
  #   assert_equal 'NP', node[:kpath]
  #   assert_equal id, node[:id]
  #   assert_equal parent_id,  node[:parent_id]
  #   assert_equal nodes_id(:zena), node[:section_id]
  #   assert_equal vers_count, Version.find(:all).size
  #   assert_equal vers_id, node.v_id
  #   assert_equal nodes_id(:zena), nodes(:status)[:section_id] # children inherit new section_id
  #   assert_equal nodes_id(:zena), nodes(:lake)[:section_id]
  # end
  # 
  # def test_cannot_change_root
  #   login(:tiger)
  #   node = secure!(Node) { Node.find(visitor.site[:root_id]) }
  #   node = node.change_to(Page)
  #   assert_nil node
  #   node = secure!(Node) { Node.find(visitor.site[:root_id]) }
  #   assert_kind_of Section, node
  # end
  
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
    assert_equal Zena::Status[:pub], wiki.v_status
    assert_equal Zena::Status[:pub], bird.v_status
    assert_equal Zena::Status[:pub], flower.v_status
    assert wiki.unpublish, 'Can unpublish publication'
    assert_equal 10, wiki.v_status
    assert_equal 10, wiki.max_status
    bird = secure!(Node) { nodes(:bird_jpg) }
    flower = secure!(Node) { nodes(:flower_jpg) }
    assert_equal 10, bird.v_status
    assert_equal 10, flower.v_status
    assert wiki.publish, 'Can publish'
    bird = secure!(Node) { nodes(:bird_jpg) }
    flower = secure!(Node) { nodes(:flower_jpg) }
    assert_equal Zena::Status[:pub], bird.v_status
    assert_equal Zena::Status[:pub], bird.max_status
    assert_equal Zena::Status[:pub], flower.v_status
  end
  
  def test_after_propose
    Version.connection.execute "UPDATE versions SET status = #{Zena::Status[:red]}, user_id=#{users_id(:tiger)} WHERE node_id IN (#{[:wiki,:bird_jpg,:flower_jpg].map{|k| nodes_id(k)}.join(',')})"
    Node.connection.execute "UPDATE nodes SET max_status = #{Zena::Status[:red]}, user_id=#{users_id(:tiger)} WHERE id IN (#{[:wiki,:bird_jpg,:flower_jpg].map{|k| nodes_id(k)}.join(',')})"
    login(:tiger)
    wiki = secure!(Node) { nodes(:wiki) }
    bird = secure!(Node) { nodes(:bird_jpg) }
    flower = secure!(Node) { nodes(:flower_jpg) }
    assert_equal Zena::Status[:red], wiki.v_status
    assert_equal Zena::Status[:red], bird.v_status
    assert_equal Zena::Status[:red], flower.v_status
    assert wiki.propose, 'Can propose for publication'
    assert_equal Zena::Status[:prop], wiki.v_status
    bird = secure!(Node) { nodes(:bird_jpg) }
    flower = secure!(Node) { nodes(:flower_jpg) }
    assert_equal Zena::Status[:prop_with], bird.v_status
    assert_equal Zena::Status[:prop_with], flower.v_status
    assert wiki.publish, 'Can publish'
    bird = secure!(Node) { nodes(:bird_jpg) }
    flower = secure!(Node) { nodes(:flower_jpg) }
    assert_equal Zena::Status[:pub], bird.v_status
    assert_equal Zena::Status[:pub], bird.max_status
    assert_equal Zena::Status[:pub], flower.v_status
  end
  
  def test_after_refuse
    Version.connection.execute "UPDATE versions SET status = #{Zena::Status[:red]}, user_id=#{users_id(:tiger)} WHERE node_id IN (#{[:wiki,:bird_jpg,:flower_jpg].map{|k| nodes_id(k)}.join(',')})"
    Node.connection.execute "UPDATE nodes SET max_status = #{Zena::Status[:red]}, user_id=#{users_id(:tiger)} WHERE id IN (#{[:wiki,:bird_jpg,:flower_jpg].map{|k| nodes_id(k)}.join(',')})"
    login(:tiger)
    wiki = secure!(Node) { nodes(:wiki) }
    assert wiki.propose, 'Can propose for publication'
    assert_equal Zena::Status[:prop], wiki.v_status
    bird = secure!(Node) { nodes(:bird_jpg) }
    flower = secure!(Node) { nodes(:flower_jpg) }
    assert_equal Zena::Status[:prop_with], bird.v_status
    assert_equal Zena::Status[:prop_with], flower.v_status
    assert wiki.refuse, 'Can refuse'
    bird = secure!(Node) { nodes(:bird_jpg) }
    flower = secure!(Node) { nodes(:flower_jpg) }
    assert_equal Zena::Status[:red], bird.v_status
    assert_equal Zena::Status[:red], bird.v_status
    assert_equal Zena::Status[:red], bird.max_status
    assert_equal Zena::Status[:red], flower.v_status
  end
  
  def test_after_publish
    Version.connection.execute "UPDATE versions SET status = #{Zena::Status[:red]}, user_id=#{users_id(:tiger)} WHERE node_id IN (#{[:wiki,:bird_jpg,:flower_jpg].map{|k| nodes_id(k)}.join(',')})"
    Node.connection.execute "UPDATE nodes SET max_status = #{Zena::Status[:red]}, user_id=#{users_id(:tiger)} WHERE id IN (#{[:wiki,:bird_jpg,:flower_jpg].map{|k| nodes_id(k)}.join(',')})"
    login(:tiger)
    wiki = secure!(Node) { nodes(:wiki) }
    assert wiki.publish, 'Can publish'
    assert_equal Zena::Status[:pub], wiki.v_status
    bird = secure!(Node) { nodes(:bird_jpg) }
    flower = secure!(Node) { nodes(:flower_jpg) }
    assert_equal Zena::Status[:pub], bird.v_status
    assert_equal Zena::Status[:pub], bird.max_status
    assert_equal Zena::Status[:pub], flower.v_status
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
    assert_equal "a--Bab*Mol", " à,--/ bab* mol".url_name!
    assert_equal "07.11.2006-mardiProchain", "07.11.2006-mardi_prochain".url_name!
    assert_equal "Node-*login", "Node-*login".url_name!
  end
  
  def test_tags
    login(:lion)
    @node = secure!(Node) { nodes(:status)  }
    assert_nothing_raised { @node.find(:all, 'set_tags') }
    assert_nil @node.find(:all, 'set_tags')
    @node.set_tag_ids = [nodes_id(:art),nodes_id(:news)]
    assert @node.save
    tags = @node.find(:all, 'set_tags')
    assert_equal 2, tags.size
    assert_equal 'art', tags[0].name
    assert_equal 'news', tags[1].name
    @node.set_tag_ids = [nodes_id(:art)]
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
    assert_equal [], node.comments
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
    node.update_attributes( :v_title=>'test' )
    discussion = node.discussion
    assert_kind_of Discussion, discussion
    assert discussion.inside?
  end
  
  def test_inside_discussion
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    node.update_attributes( :v_title=>'new status' )
    assert_equal Zena::Status[:red], node.v_status
    discussion = node.discussion
    assert_equal discussions_id(:inside_discussion_on_status), discussion[:id]
  end
  
  def test_auto_create_discussion
    login(:tiger)
    post   = secure!(Node) { Node.create_node(:v_status => Zena::Status[:pub], :v_title => 'a new post', :class => 'Post', :parent_id => nodes_zip(:cleanWater)) }
    letter = secure!(Node) { Node.create_node(:v_status => Zena::Status[:pub], :v_title => 'a letter', :class => 'Letter', :parent_id => nodes_zip(:cleanWater)) }
    assert !post.new_record?, "Not a new record"
    assert !letter.new_record?, "Not a new record"
    assert_equal Zena::Status[:pub], post.v_status, "Published"
    assert_equal Zena::Status[:pub], letter.v_status, "Published"
    assert letter.can_auto_create_discussion?
    assert post.can_auto_create_discussion?
    login(:anon)
    letter = secure!(Node) { Node.find(letter.id) }
    post   = secure!(Node) { Node.find(post.id) }
    assert !letter.can_auto_create_discussion?
    assert post.can_auto_create_discussion?
  end
  
  def test_auto_create_discussion
    login(:tiger)
    letter = secure!(Node) { Node.create_node(:v_status => Zena::Status[:pub], :v_title => 'a letter', :class => 'Letter', :parent_id => nodes_zip(:cleanWater)) }
    assert !letter.new_record?, "Not a new record"
    assert_equal Zena::Status[:pub], letter.v_status, "Published"
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
    login(:tiger)
    node = secure!(Node) { nodes(:cleanWater) }
    assert_nil node.discussion # no open discussion here
    assert_equal [], node.comments
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
    assert_raise(Zena::AccessViolation) { node.site_id = sites_id(:ocean) }
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
    assert node.errors[:parent_id], "invalid reference"
  end
  
  def test_create_node_with__parent_id
    login(:ant)
    node = secure!(Node) { Node.create_node(:_parent_id => nodes_id(:secret), :name => 'funny') }
    assert_equal nodes_id(:secret), node[:parent_id]
    assert node.new_record?, "Not saved"
    assert node.errors[:parent_id], "invalid reference"
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
    assert_equal "It's all broken", node.v_title
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
  
  def test_create_nodes_from_folder
    login(:tiger)
    parent = secure!(Project) { Project.create(:name => 'import', :parent_id => nodes_id(:zena)) }
    assert !parent.new_record?, "Not a new record"
    nodes = secure!(Node) { Node.create_nodes_from_folder(:folder => File.join(RAILS_ROOT, 'test', 'fixtures', 'import'), :parent_id => parent[:id] )}.values
    children = parent.find(:all, 'children')
    assert_equal 2, children.size
    assert_equal 4, nodes.size
    bird, doc   = nil, nil
    nodes.each do |n|
      bird = n if n[:name] == 'bird'
      doc  = n if n[:name] == 'document'    
    end
    simple = secure!(Node)  { Node.find_by_name_and_parent_id('simple', parent[:id]) }
    photos = secure!(Node) { Node.find_by_name_and_parent_id('photos', parent[:id]) }
    
    assert_equal 'bird', bird[:name]
    assert_equal 'simple', simple[:name]
    assert_equal 'The sky is blue', simple.v_title
    assert_equal 'jpg', bird.c_ext
    assert_equal 'Le septième ciel', bird.v_title
    versions = secure!(Node) { Node.find(bird[:id]) }.versions
    assert_equal 2, versions.size
    assert_equal 'fr', versions[0].lang
    assert_equal 'en', versions[1].lang
    assert_equal 'Le septième ciel', versions[0].title
    assert_equal 'Photos !', photos.v_title
    assert_match %r{Here are some photos.*!\[\]!}m, photos.v_text
    in_photos = photos.find(:all, 'children')
    assert_equal 2, in_photos.size
    
    assert_equal bird[:id], in_photos[0][:id]
    assert_equal doc[:id], in_photos[1][:id]
    doc_versions = doc.versions.sort { |a,b| a[:lang] <=> b[:lang]}
    assert_equal 2, doc_versions.size
    assert_match %r{two}, doc_versions[0].text
    assert_match %r{deux}, doc_versions[1].text
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
    assert_equal Zena::Status[:red], nodes[0].v_status
    
    nodes = secure!(Node) { Node.create_nodes_from_folder(:folder => File.join(RAILS_ROOT, 'test', 'fixtures', 'import'), :parent_id => nodes_id(:cleanWater), :defaults => { :v_status => Zena::Status[:pub] }) }.values
    assert_equal Zena::Status[:pub], nodes[0].v_status
  end
  
  def test_create_nodes_from_archive
    login(:tiger)
    res = secure!(Node) { Node.create_nodes_from_folder(:archive => uploaded_archive('import.tgz'), :parent_id => nodes_id(:zena)) }.values
    #res.each do |rec|
    #  puts "id:     #{rec[:id]}"
    #  puts "inherit: #{rec[:inherit]}"
    #  puts "rgroup_id: #{rec[:rgroup_id]}"
    #  puts "wgroup_id: #{rec[:wgroup_id]}"
    #  puts "pgroup_id: #{rec[:pgroup_id]}"
    #  puts "name:   #{rec.name}"
    #  puts "parent: #{rec.parent_id}"
    #  puts "errors: #{rec.errors.map{|k,v| "\n[#{k}] #{v}"}}"
    #end
    
    photos = secure!(Section) { Section.find_by_name('photos') }
    assert_kind_of Section, photos
    bird = secure!(Node) { Node.find_by_parent_id_and_name(photos[:id], 'bird') }
    assert_kind_of Image, bird
    assert_equal 56183, bird.c_size
    assert_equal 'Lucy in the sky', bird.v_title
    visitor.lang = 'fr'
    bird = secure!(Node) { Node.find_by_parent_id_and_name(photos[:id], 'bird') }
    assert_equal 'Le septième ciel', bird.v_title
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
  
  def test_update_nodes_from_archive
    preserving_files('test.host/data') do
      bird = node = nil
      login(:tiger)
      node = secure!(Page) { Page.create(:parent_id => nodes_id(:status), :name=>'photos', :v_title => 'my photos', :v_text => '![]!') }
      assert !node.new_record?
      assert_nothing_raised { node = secure!(Node) { Node.find_by_path( 'projects/cleanWater/status/photos') } }
      assert_raise(ActiveRecord::RecordNotFound) { node = secure!(Node) { Node.find_by_path( 'projects/cleanWater/status/photos/bird') } }
      assert_equal 'photos', node.name
      assert_no_match %r{I took during my last vacations}, node.v_text
      v1_id = node.v_id
      secure!(Node) { Node.create_nodes_from_folder(:archive => uploaded_archive('import.tgz'), :parent_id => nodes_id(:status)) }.values
      assert_nothing_raised { node = secure!(Node) { Node.find_by_path( 'projects/cleanWater/status/photos') } }
      assert_nothing_raised { bird = secure!(Node) { Node.find_by_path( 'projects/cleanWater/status/photos/bird') } }
      assert_match %r{I took during my last vacations}, node.v_text
      assert_equal v1_id, node.v_id
      assert_kind_of Image, bird
    end
  end
  
  def test_order_position
    login(:tiger)
    parent = secure!(Node) { nodes(:cleanWater) }
    children = parent.find(:all, 'children')
    assert_equal 8, children.size
    assert_equal 'bananas', children[0].name
    assert_equal 'crocodiles', children[1].name
    
    Node.connection.execute "UPDATE nodes SET position = 0.0 WHERE id = #{nodes_id(:water_pdf)}"
    Node.connection.execute "UPDATE nodes SET position = 0.1 WHERE id = #{nodes_id(:lake)}"
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
    assert_equal 'bob.c_zafu_read("truc")', Node.zafu_attribute('bob', 'c_truc')
  end
  
  def test_classes_for_form
    assert_equal [["Page", "Page"],
     ["  Project", "Project"],
     ["  Section", "Section"],
     ["    Skin", "Skin"]], Node.classes_for_form(:class=>'Page', :without=>'Document')
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
    login(:ant)
    node = secure!(Node) { nodes(:wiki) } # has an 'icon' relation
    icon = node.icon
    assert_kind_of Image, icon
    assert_equal nodes_id(:bird_jpg), icon[:id]
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
  
  # FIXME: write test
  def test_assets
    assert true
    # sweep_cache (save) => remove asset folder
    # render math ?
  end
end