require "#{File.dirname(__FILE__)}/../test_helper"


# FIXME: this needs to be finished
=begin
class MultiversionTest < ActionController::IntegrationTest


  def test_view_private_page
    ant, tiger, su = login(:ant), login(:tiger), login(:su)

    ant.get_node(:myLife)
    assert_equal 200, ant.status

    su.get_node(:myLife)
    assert_equal 200, su.status

    tiger.get_node(:myLife)
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

    tiger.get_node(:nature)
    assert tiger.redirect?
    tiger.get_node(:tree)
    assert tiger.redirect?
    tiger.get_node(:forest)
    assert tiger.redirect?

    ant.get_node(:nature)
    assert_equal 200, ant.status
    ant.get_node(:tree)
    assert_equal 200, ant.status
    ant.get_node(:forest)
    assert_equal 200, ant.status

    # node = secure!(Node) { Node.find(nodes_id(:nature)) }
    # tree = secure!(Node) { Node.find(nodes_id(:tree))   }
    # forest = secure!(Node) { Node.find(nodes_id(:forest)) }
    # assert_equal Zena::Status::Red, node.v_status
    # assert_equal Zena::Status::Red, tree.v_status
    # assert_equal Zena::Status::Red, forest.v_status
    # assert node.propose, "Propose for publication succeeds"
    #
    # # propositions
    # node = secure!(Node) { Node.find(nodes_id(:nature)) }
    # tree = secure!(Node) { Node.find(nodes_id(:tree))   }
    # forest = secure!(Node) { Node.find(nodes_id(:tree)) }
    # assert_equal Zena::Status::Prop, node.v_status
    # assert_equal Zena::Status::PropWith, tree.v_status
    # assert_equal Zena::Status::PropWith, forest.v_status
    #
    # login(:tiger)
    # # can now see all propositions
    # node = secure!(Node) { Node.find(nodes_id(:nature)) }
    # tree = secure!(Node) { Node.find(nodes_id(:tree))   }
    # forest = secure!(Node) { Node.find(nodes_id(:forest)) }
    # assert_equal Zena::Status::Prop, node.v_status
    # assert_equal Zena::Status::PropWith, tree.v_status
    # assert_equal Zena::Status::PropWith, forest.v_status
    #
    # assert node.refuse, "Can refuse publication"
    #
    # login(:ant)
    # # redactions again
    # node = secure!(Node) { Node.find(nodes_id(:nature)) }
    # tree = secure!(Node) { Node.find(nodes_id(:tree))   }
    # forest = secure!(Node) { Node.find(nodes_id(:forest)) }
    # assert_equal Zena::Status::Red, node.v_status
    # assert_equal Zena::Status::Red, tree.v_status
    # assert_equal Zena::Status::Red, forest.v_status
    # assert node.propose, "Propose for publication succeeds"
    #
    # login(:tiger)
    # # sees the propositions again
    # node = secure!(Node) { Node.find(nodes_id(:nature)) }
    # tree = secure!(Node) { Node.find(nodes_id(:tree))   }
    # forest = secure!(Node) { Node.find(nodes_id(:forest)) }
    # assert_equal Zena::Status::Prop, node.v_status
    # assert_equal Zena::Status::PropWith, tree.v_status
    # assert_equal Zena::Status::PropWith, forest.v_status
    #
    # assert node.publish, "Publication succeeds"
    #
    # login(:ant)
    # # redactions again
    # node = secure!(Node) { Node.find(nodes_id(:nature)) }
    # tree = secure!(Node) { Node.find(nodes_id(:tree))   }
    # forest = secure!(Node) { Node.find(nodes_id(:forest)) }
    # assert_equal Zena::Status::Pub, node.v_status
    # assert_equal Zena::Status::Pub, tree.v_status
    # assert_equal Zena::Status::Pub, forest.v_status
    # assert node.propose, "Propose for publication succeeds"
  end

  private
  module CustomAssertions
    include Zena::Test::Integration

    def url_for(sym)
      case sym
      when :myLife
        "people/ant/myLife"
      else
        puts "Please set url for #{sym}"
        "please/set/url/for/#{sym}"
      end
    end

    def get_node(sym)
      node = nodes(sym)
      puts path = "/#{AUTHENTICATED_PREFIX}/#{url_for(sym)}"
      get path
    end

    def propose_node(sym)
      node = nodes(sym)
      post #blah (todo)
    end

    def publish_node(sym)
      node = nodes(sym)
      post #blah (todo)
    end

    def refuse_node(sym)
      node = nodes(sym)
      post #blah (todo)
    end
  end

  def login(visitor)
    open_session do |sess|
      sess.extend(CustomAssertions)
      if visitor
        sess.post 'http://test.host/session', :login=>visitor.to_s, :password=>visitor.to_s
        assert sess.redirect?
        sess.follow_redirect!
      end
    end
  end
end
=end