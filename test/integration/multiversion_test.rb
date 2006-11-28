require "#{File.dirname(__FILE__)}/../test_helper"

class MultiversionTest < ActionController::IntegrationTest

  
  def test_view_private_page
    ant, tiger, su = login(:ant), login(:tiger), login(:su)
    
    ant.get_item(:myLife)
    assert_equal 200, ant.status
    
    su.get_item(:myLife)
    assert_equal 200, su.status
    
    tiger.get_item(:myLife)
    assert tiger.redirect?
  end
  
  def test_page_life_cycle
    ant, tiger, anonymous = login(:ant), login(:tiger), login()
    # 1. ant creates a new page in the project :cleanWater
    # page is saved
    # 1.a. redaction not seen by normal readers
    # 1.b. redaction seen by owner
    # 1.c. redaction seen by members of group 'managers'
    # 1.d. page appears in 'redactions' on owner's page
    # 2. ant comes back later and edits the page again
    # 3. ant proposes the publication
    # 3.a. page appears in 'waiting' on owner's home page
    # 3.a. publication not seen by normal readers
    # 3.b. publication seen by owner
    # 3.c. publication seen in place AND on their home page by members of group 'managers'
    # 4. tiger publishes the page
    # 4.a. page seen by all readers in place
    # 4.b. page does not appear on owner's page anymore
  end
  
  def test_child_sync
    ant, tiger = login(:ant), login(:tiger)
    
    tiger.get_item(:nature)
    assert tiger.redirect?
    tiger.get_item(:tree)
    assert tiger.redirect?
    tiger.get_item(:forest)
    assert tiger.redirect?
    
    ant.get_item(:nature)
    assert_equal 200, ant.status
    ant.get_item(:tree)
    assert_equal 200, ant.status
    ant.get_item(:forest)
    assert_equal 200, ant.status
    
    # item = secure(Item) { Item.find(items_id(:nature)) }
    # tree = secure(Item) { Item.find(items_id(:tree))   }
    # forest = secure(Item) { Item.find(items_id(:forest)) }
    # assert_equal Zena::Status[:red], item.v_status
    # assert_equal Zena::Status[:red], tree.v_status
    # assert_equal Zena::Status[:red], forest.v_status
    # assert item.propose, "Propose for publication succeeds"
    # 
    # # propositions
    # item = secure(Item) { Item.find(items_id(:nature)) }
    # tree = secure(Item) { Item.find(items_id(:tree))   }
    # forest = secure(Item) { Item.find(items_id(:tree)) }
    # assert_equal Zena::Status[:prop], item.v_status
    # assert_equal Zena::Status[:prop_with], tree.v_status
    # assert_equal Zena::Status[:prop_with], forest.v_status
    # 
    # visitor(:tiger)
    # # can now see all propositions
    # item = secure(Item) { Item.find(items_id(:nature)) }
    # tree = secure(Item) { Item.find(items_id(:tree))   }
    # forest = secure(Item) { Item.find(items_id(:forest)) }
    # assert_equal Zena::Status[:prop], item.v_status
    # assert_equal Zena::Status[:prop_with], tree.v_status
    # assert_equal Zena::Status[:prop_with], forest.v_status
    # 
    # assert item.refuse, "Can refuse publication"
    # 
    # visitor(:ant)
    # # redactions again
    # item = secure(Item) { Item.find(items_id(:nature)) }
    # tree = secure(Item) { Item.find(items_id(:tree))   }
    # forest = secure(Item) { Item.find(items_id(:forest)) }
    # assert_equal Zena::Status[:red], item.v_status
    # assert_equal Zena::Status[:red], tree.v_status
    # assert_equal Zena::Status[:red], forest.v_status
    # assert item.propose, "Propose for publication succeeds"
    # 
    # visitor(:tiger)
    # # sees the propositions again
    # item = secure(Item) { Item.find(items_id(:nature)) }
    # tree = secure(Item) { Item.find(items_id(:tree))   }
    # forest = secure(Item) { Item.find(items_id(:forest)) }
    # assert_equal Zena::Status[:prop], item.v_status
    # assert_equal Zena::Status[:prop_with], tree.v_status
    # assert_equal Zena::Status[:prop_with], forest.v_status
    # 
    # assert item.publish, "Publication succeeds"
    # 
    # visitor(:ant)
    # # redactions again
    # item = secure(Item) { Item.find(items_id(:nature)) }
    # tree = secure(Item) { Item.find(items_id(:tree))   }
    # forest = secure(Item) { Item.find(items_id(:forest)) }
    # assert_equal Zena::Status[:pub], item.v_status
    # assert_equal Zena::Status[:pub], tree.v_status
    # assert_equal Zena::Status[:pub], forest.v_status
    # assert item.propose, "Propose for publication succeeds"
  end
  
  private
  module CustomAssertions
    def url_for(sym)
      case sym
      when :myLife
        "people/ant/myLife"
      else
        puts "Please set url for #{sym}"
        "please/set/url/for/#{sym}"
      end
    end
    def get_item(sym)
      item = items(sym)
      puts path = "/#{AUTHENTICATED_PREFIX}/#{url_for(sym)}"
      get path
    end
    def propose_item(sym)
      item = items(sym)
      post #blah (todo)
    end
    def publish_item(sym)
      item = items(sym)
      post #blah (todo)
    end
    def refuse_item(sym)
      item = items(sym)
      post #blah (todo)
    end
  end

  def login(visitor)
    open_session do |sess|
      sess.extend(CustomAssertions)
      if visitor
        sess.post 'login', :user=>{:login=>visitor.to_s, :password=>visitor.to_s}
        assert_equal users_id(visitor), sess.session[:user][:id]
        assert sess.redirect?
        sess.follow_redirect!
      end
    end
  end
end
