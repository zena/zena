require File.dirname(__FILE__) + '/../test_helper'

class MultiVersionTest < ZenaTestUnit
  
  def node_defaults
    {
    :name => 'hello',
    :parent_id => nodes_id(:zena),
    }
  end
  
  def test_find_node_by_version
    login(:ant)
    node = secure!(Node) { Node.version(versions_id(:lake_red_en)) }
    assert_equal "this is a new redaction for lake", node.v_comment
    assert_nothing_raised { node = secure!(Node) { Node.version(versions_id(:zena_en)) } }
    assert_raise(ActiveRecord::RecordNotFound) { node = secure!(Node) { Node.version(versions_id(:secret_en)) } }
    login(:lion)
    assert_nothing_raised { node = secure!(Node) { Node.version(versions_id(:lake_red_en)) } }
  end
  
  def test_find_version
    login(:tiger) # can_drive?
    node = secure!(Node) { nodes(:lake) }
    assert_equal versions_id(:lake_en), node.version(1)[:id]
    node = secure!(Node) { nodes(:lake) } # reload
    assert_raise(ActiveRecord::RecordNotFound) { node.version(2) } # redaction from ant
    Node.connection.execute "UPDATE versions set status = #{Zena::Status[:prop]} where id = #{versions_id(:lake_red_en)}"
    assert_equal versions_id(:lake_red_en), node.version(2)[:id] 
    node = secure!(Node) { nodes(:lake) } # reload
    assert_raise(ActiveRecord::RecordNotFound) { node.version(7) }
    login(:ant)
    visitor.lang = 'en'
    node = secure!(Node) { nodes(:lake) } # reload
    assert_equal versions_id(:lake_red_en), node.version[:id]
    node = secure!(Node) { nodes(:lake) } # reload
    assert_equal versions_id(:lake_en), node.version(:pub)[:id]
  end
  
  def test_find_version_latest_replaced
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    pub_version_id = node.v_id
    assert_equal 2, node.versions.size
    assert_equal Zena::Status[:pub], node.v_status
    assert node.update_attributes(:v_title => 'great', :v_text => 'mind')
    node = secure!(Node) { nodes(:status) }
    assert_equal Zena::Status[:red], node.v_status
    red_version_id = node.v_id
    assert_not_equal pub_version_id, red_version_id
    assert node.remove
    node = secure!(Node) { nodes(:status) }
    assert_equal pub_version_id, node.v_id
    assert node.update_attributes(:v_title => 'slow')
    assert_not_equal pub_version_id, node.v_id
    assert_not_equal red_version_id, node.v_id
    assert_not_equal 'mind', node.v_text
    assert_equal 4, node.versions.size
  end
  
  def test_remove_attributes_with_same_value
    login(:ant)
    node = secure!(Node) { nodes(:status) }
    current = { :name => "status",
      :position => "1",
      :v_publish_from => "2006-03-10",
      :v_summary => "status summary",
      :v_text => "status text",
      :v_title => "Etat des travaux"}
    assert_equal Hash[:v_title=>'hey', :d_what=>'ever'], node.remove_attributes_with_same_value(current.merge(:v_title=>'hey', :d_what=>'ever'))
  end
  
  def test_remove_attributes_with_same_value_empty_date
    login(:ant)
    node = secure!(Node) { nodes(:status) }
    current = { :name => "status",
      :position => "1",
      :v_publish_from => "2006-03-10",
      :v_summary => "status summary",
      :v_text => "status text",
      :v_title => "Etat des travaux"}
    assert_equal Hash[:v_title=>'hey', :d_what=>'ever', :v_publish_from=>nil], node.remove_attributes_with_same_value(current.merge(:v_title=>'hey', :d_what=>'ever', :v_publish_from=>nil))  
    assert_equal Hash[:v_title=>'hey', :d_what=>'ever', :v_publish_from=>''], node.remove_attributes_with_same_value(current.merge(:v_title=>'hey', :d_what=>'ever', :v_publish_from=>''))
  end
  
  def test_update_same_attributes
    login(:tiger)
    visitor.lang = 'en'
    node = secure!(Node) { nodes(:people) }
    v_id = node.v_id
    v_nu = node.v_number
    assert node.update_attributes(:v_title => node.v_title, :name => 'satori')
    assert_equal v_id, node.v_id
    assert_equal v_nu, node.v_number
    assert_equal 'satori', node.name
  end
  
  def test_accessors
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    assert_equal "status title", node.v_title
    assert_equal "status comment", node.v_comment
    assert_equal "status summary", node.v_summary
    assert_equal "status text", node.v_text
  end
  
  def test_content_accessors
    content = Struct.new(:hello, :name).new('hello', 'guys')
    login(:tiger)
    node = secure!(Node) { nodes(:zena) }
    node.edit!
    node.version.instance_eval { @content = @redaction_content = content; def content_class; @content.class; end }
    assert_equal 'hello', node.c_hello
    assert_equal 'guys', node.c_name
    node.c_hello = 'Thanks'
    node.c_name = 'Matz' 
    assert_equal 'Thanks', node.c_hello
    assert_equal 'Matz', node.c_name
  end
  
  def test_accessors_bad_attributes
    login(:tiger)
    node = secure!(Node) { nodes(:zena) }
    assert_nothing_raised(NoMethodError) { node.v_smol }
    assert_nothing_raised(NoMethodError) { node.v_smol = 'io' }
    assert_nothing_raised(NoMethodError) { node.c_smol }
    assert_nothing_raised(NoMethodError) { node.c_smol = 'io' }
    assert_nil node.v_shmol
    assert_nil node.c_shmol
    
    node = secure!(Node) { nodes(:bird_jpg) }
    assert_nothing_raised(NoMethodError) { node.v_smol }
    assert_nothing_raised(NoMethodError) { node.v_smol = 'io' }
    assert_nothing_raised(NoMethodError) { node.c_smol }
    assert_nothing_raised(NoMethodError) { node.c_smol = 'io' }
    assert_nil node.v_shmol
    assert_nil node.c_shmol
  end
    
  
  def test_new_has_redaction
    login(:ant)
    node = secure!(Node) { Node.new() }
    assert_equal Zena::Status[:red], node.v_status
    assert_equal users_id(:ant), node.v_user_id
  end
  
  def test_new_with_attributes
    login(:ant)
    attrs = node_defaults
    attrs[:v_title] = "Jolly Jumper"
    attrs[:v_summary] = "Jolly summary"
    attrs[:v_comment] = "Jolly comment"
    attrs[:v_text] = "Jolly text"
    node = secure!(Node) { Node.new(attrs) }
    assert node.save
    node = secure!(Node) { Node.find(node.id) }
    assert_equal Zena::Status[:red], node.v_status
    assert_equal "Jolly Jumper", node.v_title
    assert_equal "Jolly summary", node.v_summary
    assert_equal "Jolly comment", node.v_comment
    assert_equal "Jolly text", node.v_text
  end
  
  def test_create
    login(:ant)
    attrs = node_defaults
    attrs[:v_title] = "Inner voice"
    node = secure!(Node) { Node.create(attrs) }
    node = secure!(Node) { Node.find(node.id) }
    assert_equal Zena::Status[:red], node.v_status
    assert_equal "Inner voice", node.v_title
  end
  
  def test_version_lang
    login(:ant) # lang = fr
    node = secure!(Node) { nodes(:opening)  }
    assert_equal "fr", node.v_lang
    assert_equal "ouverture du parc", node.v_title
    visitor.lang = "en"
    node = secure!(Node) { nodes(:opening)  }
    assert_equal "en", node.v_lang
    assert_equal "parc opening", node.v_title
    visitor.lang = 'ru'
    node = secure!(Node) { nodes(:opening)  }
    assert_equal "fr", node.v_lang
    assert_equal "ouverture du parc", node.v_title
    login(:lion) # lang = en
    node = secure!(Node) { nodes(:opening)  }
    assert_equal "en", node.v_lang
    assert_equal "parc opening", node.v_title
    visitor.lang = 'ru'
    node = secure!(Node) { nodes(:opening)  }
    assert_equal "fr", node.v_lang
    assert_equal "ouverture du parc", node.v_title
  end
  
  def test_version_text_and_summary
    login(:ant)
    node = secure!(Node) { nodes(:ant)  }
    class << node
      def text
        "Node text"
      end
      def summary
        "Node summary"
      end
    end
    assert_equal "Node text", node.text
    assert_equal "Ants work hard", node.v_text
    assert_equal "Node summary", node.summary
    assert_equal "I am an ant", node.v_summary
  end
  
  def test_editions
    login(:ant)
    node = secure!(Node) { nodes(:opening)  }
    editions = node.editions
    assert_equal 2, editions.count
  end
  
  def test_edit_get_redaction
    login(:ant)
    node = secure!(Node) { nodes(:opening)  }
    assert_equal "fr", node.v_lang
    assert_equal "french opening", node.v_comment
  end
  
  def test_set_redaction
    login(:tiger)
    visitor.lang = 'es'
    node = secure!(Node) { nodes(:status) }
    node.v_title = 'labias'
    assert_equal 'es', node.v_lang
    assert_equal 'labias', node.v_title
    assert node.v_new_record?
  end
  
  def test_proposition
    login(:tiger)
    visitor.lang = 'en'
    node = secure!(Node) { nodes(:lake)  }
    assert_equal Zena::Status[:pub], node.v_status , "Any visitor sees the publication"
    assert_equal versions_id(:lake_en) , node.v_id
    login(:ant)
    visitor.lang = 'en'
    node = secure!(Node) { nodes(:lake)  }
    assert_equal Zena::Status[:red], node.v_status , "Owner of a redaction sees the redaction"
    assert_equal versions_id(:lake_red_en) , node.v_id
    assert node.propose , "Node proposed for publication"
    
    node = secure!(Node) { nodes(:lake)  }
    assert_equal Zena::Status[:prop], node.v_status , "Owner sees the proposition"
    assert_equal versions_id(:lake_red_en) , node.v_id
    
    login(:anon) # public
    node = secure!(Node) { nodes(:lake)  }
    assert_equal Zena::Status[:pub], node.v_status , "Visitor sees the publication"
    assert_equal versions_id(:lake_en) , node.v_id
    
    login(:tiger)
    visitor.lang = 'en'
    node = secure!(Node) { nodes(:lake)  }
    assert_equal Zena::Status[:prop], node.v_status , "Publisher sees the proposition"
    assert_equal versions_id(:lake_red_en) , node.v_id
  end
  
  def test_can_edit
    login(:ant)
    visitor.lang = 'en'
    node = secure!(Node) { nodes(:lake)  }
    node2 = secure!(Node) { nodes(:status)  }
    assert node.can_edit?
    assert node2.can_edit?
    login(:tiger)
    visitor.lang = 'en'
    node = secure!(Node) { nodes(:lake)  }
    node2 = secure!(Node) { nodes(:status)  }
    assert ! node.can_edit?
    assert node2.can_edit?
  end
  
  def test_do_edit
    login(:ant)
    node = secure_write(Node) { nodes(:wiki)  }
    node.edit!
    assert_equal Zena::Status[:red], node.v_status
    assert node.v_new_record?
  end
  
  def test_update_without_fuss
    login(:tiger)
    node = secure!(Node) { nodes(:wiki) }
    assert_equal Zena::Status[:pub], node[:max_status]
    node.send(:update_attribute_without_fuss, :max_status, Zena::Status[:red])
    node = secure!(Node) { nodes(:wiki) }
    assert_equal Zena::Status[:red], node[:max_status]
  end
  
  def test_update_without_fuss_time
    login(:tiger)
    node = secure!(Node) { nodes(:wiki) }
    assert_equal Time.gm(2006,3,10), node[:publish_from]
    node.send(:update_attribute_without_fuss, :publish_from, Time.gm(2006,12,10))
    node = secure!(Node) { nodes(:wiki) }
    assert_equal Time.gm(2006,12,10), node[:publish_from]
  end
  
  def test_update_new_red
    login(:ant)
    node = secure_write(Node) { nodes(:wiki)  }
    assert node.edit! , "Edit succeeds"
    attrs = { :v_comment=>"hey I'm new !", :v_title=>"super new" }
    assert node.update_attributes( attrs ) , "Edit succeeds"
    assert ! node.v_new_record? , "Not a new redaction"
    assert_equal "super new", node.v_title
    # find it
    node = secure_write(Node) { nodes(:wiki)  }
    assert node.edit! , "Edit succeeds"
    assert_equal "hey I'm new !", node.v_comment
    assert_equal "super new", node.v_title
    assert_equal Zena::Status[:red], node.v_status
    assert node.update_attributes( :v_title=>"bee bop a lula" ) , "Edit succeeds"
    assert_equal "bee bop a lula", node.v_title
    redactions = Version.find(:all, :conditions=>['node_id = ? AND status = ?', nodes_id(:wiki), Zena::Status[:red]])
    assert_equal 1, redactions.size
    
    # no two redactions for the same language
    login(:tiger)
    visitor.lang = "fr"
    node = secure_write(Node) { nodes(:wiki)  }
    assert ! node.edit! , "Edit fails"
    assert ! node.update_attributes( :v_title=>"Mon amour") , "Edit fails"
    
    # can add redactions for different languages
    visitor.lang = "de"
    visitor.site.languages = 'fr,en,de'
    node = secure_write(Node) { nodes(:wiki)  }
    assert node.update_attributes( :v_title=> "Spieluhr") , "Edit succeeds"
    redactions = Version.find(:all, :conditions=>['node_id = ? AND status = ?', nodes_id(:wiki), Zena::Status[:red]])
    assert_equal 2, redactions.size
  end
  
  def test_update_attributes
    login(:ant)
    visitor.lang = 'en'
    node = secure_write(Node) { nodes(:lake)  }
    assert node.edit! , "Edit succeeds"
    assert_equal "The lake we love", node.v_title
    assert_equal Zena::Status[:red], node.v_status
    attrs = { :v_comment=>"hey I'm new !", :v_title=>"super new" }
    assert node.update_attributes( attrs ) , "Edit succeeds"
    
    node = secure_write(Node) { nodes(:lake)  }
    assert node.edit! , "Edit succeeds"
    assert_equal "hey I'm new !", node.v_comment
    assert_equal "super new", node.v_title
    assert_equal Zena::Status[:red], node.v_status
  end
  
  def test_update_attributes_bad_user
    login(:tiger)
    node = secure_write(Node) { nodes(:lake)  }
    assert ! node.edit! , "Edit fails"
    assert_equal Zena::Status[:pub], node.v_status
    attrs = { :v_comment=>"hey I'm new !", :v_title=>"super new" }
    assert ! node.update_attributes( attrs ) , "Edit fails"
  end
  
  def test_update_cannot_create_redaction
    # ant already has a redaction for 'lake', lion cannot create another
    login(:lion)
    visitor.lang = 'en'
    node = secure!(Node) { nodes(:lake)  }
    attrs = { :rgroup_id => 4, :v_title => "Manager's lake" }
    assert ! node.update_attributes( attrs ), "Update attributes fails"
    assert node.errors[:base] , "(ant) is editing this node"
  end
  
  def test_update_attributes_ok
    # changes node and creates a new redaction
    login(:lion)
    visitor.lang = 'ru'
    node = secure!(Node) { nodes(:lake)  }
    attrs = { :inherit=>0, :rgroup_id => 4, :v_title => "Manager's lake"}
    assert !node.update_attributes( attrs ) #, "Update attributes succeeds"
    assert_equal 'not valid', node.errors[:v_lang]
    visitor.site.languages = 'en,fr,ru'
    assert node.update_attributes( attrs ) #, "Update attributes succeeds"
    assert_equal 4, node.rgroup_id
    assert_equal 3, node.wgroup_id
    assert_equal 4, node.pgroup_id
    assert_equal 0, node.inherit
    assert_equal "Manager's lake", node.v_title
  end
  
  def test_create_bad_attributes
    login(:ant)
    attrs = {
    :name => 'new_with_attributes',
    :rgroup_id => 3,
    :wgroup_id => 3,
    :pgroup_id => 4,
    :parent_id => nodes_id(:secret),
    :v_title => "A New Node With A Redaction",
    :v_summary => "new summary"
    }
    node = secure!(Node) { Node.new( attrs ) }
    assert ! node.save , "Save fails"
    assert node.errors[:parent_id] , "Errors on parent_id"
  end
  
  def test_create_with_attributes_ok
    login(:tiger)
    attrs = {
    :name => 'new-with-attributes',
    :rgroup_id => 3,
    :wgroup_id => 3,
    :pgroup_id => 4,
    :parent_id => 1,
    :v_title => "A New Node With A Redaction",
    :v_summary => "new summary"
    }
    node = secure!(Node) { Node.create( attrs ) }
    assert ! node.new_record? , "Not a new record"
    assert ! node.v_new_record? , "Not a new redaction"
    assert_equal Zena::Status[:red], node.v_status
    assert_equal "A New Node With A Redaction", node.v_title
    assert_equal "new-with-attributes", node.name
    assert_equal 3, node.rgroup_id
  end
  
  def test_save_redaction
    login(:ant)
    visitor.lang = 'en'
    node = secure!(Node) { nodes(:lake)  }
    node.edit!
    version_id = node.v_id
    assert_equal "The lake we love", node.v_title
    assert_equal versions_id(:lake_red_en), version_id
    # edit node with form...
    # post modifications
    node = secure!(Node) { Node.version(node.v_id) }
    #assert node.update_attributes( :v_title => "Funny lake" ) , "Edit succeeds"
    
    node.update_attributes( :v_title => "Funny lake" )
    err node
    assert_equal "Funny lake", node.v_title
    assert_equal version_id, node.v_id
    # find redaction again
    node = secure!(Node) { nodes(:lake)  }
    node.edit!
    assert_equal "Funny lake", node.v_title
    assert_equal version_id, node.v_id
  end
  
  def test_propose_node_ok
    login(:ant)
    node = secure!(Node) { Node.version(versions_id(:lake_red_en)) }
    assert node.propose, "Propose for publication succeeds"
  end
    
  def test_propose_node_fails
    login(:tiger)
    node = secure!(Node) { Node.version(versions_id(:lake_red_en)) }
    assert ! node.propose, "Propose for publication fails"
  end
  
  def test_publish_node_ok
    login(:ant)
    node = secure!(Node) { Node.version(versions_id(:lake_red_en)) }
    assert node.propose, "Propose for publication succeeds"
    login(:tiger)
    visitor.lang = 'en'
    node = secure!(Node) { nodes(:lake)  }
    assert_equal versions_id(:lake_red_en), node.v_id, "Publisher sees the proposition"
    assert node.publish
    node = secure!(Node) { nodes(:lake)  }
    assert_equal "The lake we love", node.v_title
    assert_equal versions_id(:lake_red_en), node.v_id
    assert_equal 1, node.editions.size
  end
  
  def test_publish_with_two_lang_red
    login(:tiger)
    visitor.lang = 'en'
    node = secure!(Node) { nodes(:opening) }
    assert_equal 3, Version.find(:all, :conditions=>["node_id = ?", node[:id]]).size
    assert_equal 1, Version.find(:all, :conditions=>["node_id = ? AND status=#{Zena::Status[:red]}", node[:id]]).size
    assert node.update_attributes(:v_title=>'new title'), "Can create new redaction"
    assert_equal 2, Version.find(:all, :conditions=>["node_id = ? AND status=#{Zena::Status[:pub]}", node[:id]]).size
    assert_equal 2, Version.find(:all, :conditions=>["node_id = ? AND status=#{Zena::Status[:red]}", node[:id]]).size
    assert node.publish, "Can publish"
    assert_equal 4, Version.find(:all, :conditions=>["node_id = ?", node[:id]]).size
    assert_equal 1, Version.find(:all, :conditions=>["node_id = ? AND status=#{Zena::Status[:pub]} AND lang='fr'", node[:id]]).size
    assert_equal 1, Version.find(:all, :conditions=>["node_id = ? AND status=#{Zena::Status[:pub]} AND lang='en'", node[:id]]).size
  end
  
  def test_publish_node_fails
    login(:ant)
    node = secure!(Node) { Node.version(versions_id(:lake_red_en)) }
    assert ! node.publish, "Publication fails"
    login(:tiger)
    pub_node = secure!(Node) { nodes(:lake)  }
    assert_not_equal pub_node.v_id, versions_id(:lake_red_en)
  end
  
  def test_publish_new_lang_new_author
    login(:tiger)
    visitor.lang = 'fr'
    node = secure!(Node) { nodes(:lake)  }
    assert_equal 1, node.editions.size, "English edition exists"
    assert node.update_attributes( :v_title => "Joli petit lac" )
    assert node.can_publish?
    assert node.publish
    node = secure!(Node) { nodes(:lake)  } # reload
    assert_equal 2, node.editions.size, "English and french editions"
    assert_equal ["en", "fr"], node.traductions.map{|t| t[:lang]}.sort
  end
  
  def test_publish_replaced_from_other_author
    login(:tiger)
    node = secure!(Page) { Page.create(:name => 'foo', :v_title=> 'Bar', :v_text => 'baz', :parent_id => nodes_id(:status))}
    assert !node.new_record?
    assert node.publish
    vers_number = node.v_number
    login(:lion)
    node = secure!(Page) { Page.find(node[:id])}
    assert node.update_attributes(:v_text => 'lion', :v_status => Zena::Status[:pub])
    assert_equal Zena::Status[:pub], node.v_status
    assert_equal 2, node.v_number
    
    # rollback
    login(:lion)
    node = secure!(Page) { Page.find(node[:id])}
    assert node.version(vers_number) # load with initial version
    assert node.publish # lion publishes 'replaced' version by 'tiger'    
  end
  
  def test_publish_with_custom_date
    login(:tiger)
    node = secure!(Node) { nodes(:wiki)  }
    assert_equal 1, node.editions.size, "Only one editions"
    assert_equal Zena::Status[:pub], node.v_status
    assert node.update_attributes( :v_title => "OuiOui", :v_publish_from => "2007-01-03" )
    assert node.publish
    node = secure!(Node) { nodes(:wiki)  } # reload
    assert_equal 2, node.versions.size, "Two versions"
    assert_equal "OuiOui", node.v_title
    assert_equal Time.gm(2007,1,3), node.v_publish_from
  end
  
  def test_unpublish_all
    login(:tiger)
    visitor.lang = 'fr'
    node = secure!(Node) { nodes(:status)  }
    assert node.unpublish # remove publication
    assert_equal Zena::Status[:rem], node.v_status
    assert_equal Zena::Status[:pub], node.max_status
    node = secure!(Node) { nodes(:status)  }
    assert_equal Zena::Status[:pub], node.v_status
    assert node.unpublish # remove publication
    assert_equal Zena::Status[:rem], node.v_status
    assert_equal Zena::Status[:rem], node.max_status
  end
  
  def test_can_man_cannot_publish
    login(:ant)
    node = secure!(Note) { Note.create(:name=>'hello', :parent_id=>nodes_id(:cleanWater)) }
    assert !node.new_record?
    assert node.can_drive?, "Can drive"
    assert node.can_manage?, "Can manage"
    assert !node.private?, "Not private"
    assert !node.can_publish?, "Cannot publish (not private)"
    assert !node.publish, "Cannot publish"
    
    node.errors.clear
    
    assert node.update_attributes(:inherit=>-1)
    assert node.can_drive?, "Can drive"
    assert node.can_manage?, "Can manage"
    assert node.can_publish?, "Can publish (private)"
    assert node.publish, "Can publish"
  end
  
  def test_unpublish
    login(:lion)
    node = secure!(Node) { nodes(:bananas)  }
    assert node.unpublish # unpublish version
    assert_equal Zena::Status[:rem], node.v_status
    assert_equal Zena::Status[:rem], node.max_status
  end
  
  def test_can_unpublish_version
    login(:lion)
    node = secure!(Node) { nodes(:lion) }
    pub_version = node.version
    assert node.can_unpublish?
    assert node.update_attributes(:v_title=>'leopard')
    assert_equal Zena::Status[:red], node.v_status
    assert !node.can_unpublish?
    assert node.can_unpublish?(pub_version)
  end
  
  def test_backup
    login(:ant)
    visitor.lang = 'en'
    node = secure!(Node) { nodes(:lake) }
    assert_equal Zena::Status[:red], node.v_status
    assert_equal versions_id(:lake_red_en), node.v_id
    assert node.backup, "Backup succeeds"
    old_version = versions(:lake_red_en)
    assert_equal Zena::Status[:rep], old_version.status
    
    node = secure!(Node) { nodes(:lake) }
    assert_equal Zena::Status[:red], node.v_status
    assert_not_equal versions_id(:lake_red_en), node.v_id
  end
  
  def test_redit
    login(:ant)
    visitor.lang = 'en'
    node = secure!(Node) { nodes(:lake) }
    assert_equal Zena::Status[:red], node.v_status
    assert_equal versions_id(:lake_red_en), node.v_id
    assert node.propose, "Can propose"
    login(:tiger)
    node = secure!(Node) { nodes(:lake) }
    assert node.publish, "Can publish"
    assert_equal Zena::Status[:pub], node.v_status
    assert node.redit, "Can re-edit node"
    
    login(:ant)
    visitor.lang = 'en'
    node = secure!(Node) { nodes(:lake) }
    assert_equal Zena::Status[:red], node.v_status
    assert_equal versions_id(:lake_red_en), node.v_id
  end
  
  def test_remove_own_redaction
    login(:ant)
    visitor.lang = 'en'
    node = secure!(Node) { nodes(:lake) }
    assert !node.can_drive?
    assert_equal Zena::Status[:red], node.v_status
    assert_equal versions_id(:lake_red_en), node.v_id
    assert node.remove, "Can remove"
    assert_equal Zena::Status[:rem], node.v_status
  end
  
  def test_not_owner_can_remove
    login(:lion)
    node = secure!(Node) { nodes(:status) }
    assert_equal users_id(:ant), node.user_id
    assert node.can_apply?(:unpublish)
    assert node.unpublish
    assert node.can_apply?(:destroy_version)
    assert node.destroy_version
    # second version
    node = secure!(Node) { nodes(:status) }
    assert_equal users_id(:ant), node.user_id
    assert node.can_apply?(:unpublish)
    assert node.unpublish
    assert node.can_apply?(:destroy_version)
    assert node.destroy_version
    assert_raise(ActiveRecord::RecordNotFound) { nodes(:status) }
  end
  
  def test_traductions
    login(:lion) # lang = 'en'
    node = secure!(Node) { nodes(:status) }
    trad = node.traductions
    assert_equal 2, trad.size
    trad_node = trad[0].node
    assert_equal node.object_id, trad_node.object_id # make sure object is not reloaded and not secured
    assert_equal 'en', node.v_lang
    assert_equal 'fr', trad[1][:lang]
    node = secure!(Node) { nodes(:wiki) }
    trad = node.traductions
    assert_equal 1, trad.size
  end
  
  def test_dynamic_attributes
    login(:lion)
    node = secure!(Node) { nodes(:status) }
    node.d_bolo = 'spaghetti bolognese'
    assert node.save, "Can save node"
    
    # reload
    node = secure!(Node) { nodes(:status) }
    assert_equal 'spaghetti bolognese', node.d_bolo
  end
  
  def test_root_never_empty?
    login(:lion)
    Node.connection.execute "UPDATE nodes SET parent_id = NULL WHERE parent_id = #{nodes_id(:zena)}"
    node = secure!(Node) { nodes(:zena) }
    assert !node.empty?
  end
  
  def test_empty?
    login(:lion)
    Node.connection.execute "UPDATE nodes SET parent_id = NULL WHERE parent_id = #{nodes_id(:people)} AND id <> #{nodes_id(:ant)}"
    node = secure!(Node) { nodes(:people) }
    assert_nil node.find(:all, 'nodes')
    assert !node.empty?
    Node.connection.execute "UPDATE nodes SET parent_id = NULL WHERE parent_id = #{nodes_id(:people)}"
    node = secure!(Node) { nodes(:people) }
    assert node.empty?
  end
  
  def test_destroy
    login(:lion)
    node = secure!(Node) { nodes(:status) }
    sub  = secure!(Page) { Page.create(:parent_id => node[:id], :v_title => 'hello') }
    err sub
    assert !sub.new_record?
    assert_equal 2, node.versions.size
    assert_equal 1, node.send(:all_children).size
    
    assert !node.can_destroy_version? # versions are not in 'deleted' status
    Node.connection.execute "UPDATE versions SET status = #{Zena::Status[:del]} WHERE node_id = #{nodes_id(:status)}"
    node = secure!(Node) { nodes(:status) }
    assert node.can_destroy_version? # versions are now in 'deleted' status
    assert node.destroy_version      # 1 version left
    assert_equal 1, node.versions.size
    assert !node.destroy
    assert_equal 'contains subpages', node.errors[:base]
    assert sub.remove
    assert sub.destroy_version # destroy all
    node = secure!(Node) { nodes(:status) }
    assert node.destroy_version # destroy all
    assert_raise(ActiveRecord::RecordNotFound) { nodes(:status) }
  end
  
  def test_auto_publish_by_status
    # set v_status = 50 ===> publish
    login(:lion)
    node = secure!(Node) { nodes(:status) }
    assert_equal Zena::Status[:pub], node.v_status
    assert_equal 'status title', node.v_title
    assert_equal 1, node.v_number
    node.update_attributes(:v_title => "Statues are better", 'v_status' => Zena::Status[:pub])
    assert_equal Zena::Status[:pub], node.v_status
    assert_equal 3, node.v_number
    assert_equal 'Statues are better', node.v_title
  end
  
  def test_auto_publish
    # set site.auto_publish ===> publish
    Site.connection.execute "UPDATE sites set auto_publish = 1, redit_time = 0 WHERE id = 1"
    login(:lion)
    node = secure!(Node) { nodes(:status) }
    assert_equal Zena::Status[:pub], node.v_status
    assert_equal 'status title', node.v_title
    assert_equal 1, node.v_number
    node.update_attributes(:v_title => "Statues are better")
    assert_equal Zena::Status[:pub], node.v_status
    assert_equal 3, node.v_number
    assert_equal 'Statues are better', node.v_title
  end
  
  def test_auto_publish_in_redit_time
    # set site.auto_publish      ===> publish
    # now < updated + redit_time ===> update current publication
    Site.connection.execute "UPDATE sites set auto_publish = 1, redit_time = 7200 WHERE id = 1"
    Version.connection.execute "UPDATE versions set updated_at = '#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}' WHERE id = #{versions_id(:status_en)}"
    login(:ant)
    visitor.lang = 'en'
    node = secure!(Node) { nodes(:status) }
    assert_equal Zena::Status[:pub], node.v_status
    assert_equal 'status title', node.v_title
    assert_equal 1, node.v_number
    assert_equal users_id(:ant), node.v_user_id
    assert node.v_updated_at < Time.now + 600
    assert node.v_updated_at > Time.now - 600
    node.update_attributes(:v_title => "Statues are better")
    assert_equal Zena::Status[:pub], node.v_status
    assert_equal 1, node.v_number
    assert_equal versions_id(:status_en), node.v_id
    assert_equal 'Statues are better', node.v_title
  end

  def test_publish_after_save_in_redit_time
    # set site.auto_publish      ===> publish
    # now < updated + redit_time ===> update current publication
    Site.connection.execute "UPDATE sites set auto_publish = 0, redit_time = 7200 WHERE id = 1"
    Version.connection.execute "UPDATE versions set updated_at = '#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}' WHERE id = #{versions_id(:status_en)}"
    login(:ant)
    visitor.lang = 'en'
    node = secure!(Node) { nodes(:status) }
    assert_equal Zena::Status[:pub], node.v_status
    assert_equal 'status title', node.v_title
    assert_equal 1, node.v_number
    assert_equal users_id(:ant), node.v_user_id
    assert node.v_updated_at < Time.now + 600
    assert node.v_updated_at > Time.now - 600
    node.update_attributes(:v_title => "Statues are better", :v_status => Zena::Status[:pub])
    assert_equal Zena::Status[:pub], node.v_status
    assert_equal 1, node.v_number
    assert_equal versions_id(:status_en), node.v_id
    assert_equal 'Statues are better', node.v_title
  end
  
  def test_create_auto_publish
    Site.connection.execute "UPDATE sites set auto_publish = 1, redit_time = 7200 WHERE id = 1"
    login(:tiger)
    node = secure!(Node) { Node.create( :parent_id => 1, :v_title => "This one should auto publish" ) }
    assert ! node.new_record? , "Not a new record"
    assert ! node.v_new_record? , "Not a new redaction"
    assert_equal Zena::Status[:pub], node.v_status, "published version"
    assert node.publish_from > Time.now - 10
    assert node.publish_from < Time.now + 10
    assert node.v_publish_from > Time.now - 10
    assert node.v_publish_from < Time.now + 10
    assert_equal Zena::Status[:pub], node.max_status, "published node"
    assert_equal "This one should auto publish", node.v_title
  end
end