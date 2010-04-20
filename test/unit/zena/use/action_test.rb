require 'test_helper'

class ActionTest < Zena::View::TestCase
  
  context 'An anonymous user' do
    setup do
      # User status
      User.connection.execute "UPDATE users SET status = #{User::Status[:user]} WHERE id = #{users_id(:anon)}"
      login(:anon)
    end
    
    context 'on a node without public write access' do
      subject do
        visiting(:cleanWater)
      end
    
      should 'return an empty string on node_actions' do
        assert_equal '', node_actions(subject, :actions => :all)
      end
    end # on a node without public write access
    
    context 'on a node with public write access' do
      subject do
        visiting(:bird_jpg)
      end
    
      should 'return a link to edit on node_actions' do
        assert_match %Q{a[@href='/nodes/#{subject.zip}/versions/0/edit']}, node_actions(subject, :actions => :all)
      end
      
      should 'return a link to drive on node_actions' do
        assert_match %Q{a[@href='/nodes/#{subject.zip}/edit']}, node_actions(subject, :actions => :all)
      end
    end # on a node without public write access
  end # Without a login
  
  context 'With a logged in user' do
    setup do
      login(:ant)
    end
    
    subject do
      visiting(:cleanWater)
    end
    
    context 'without drive access' do
      should 'return a link to edit on node_actions' do
        assert_match %Q{a[@href='/nodes/#{subject.zip}/versions/0/edit']}, node_actions(subject, :actions => :all)
      end
    
      should 'not show drive links on node_actions' do
        assert_no_match %Q{a[@href='/nodes/#{subject.zip}/edit']}, node_actions(subject, :actions => :all)
      end
    end
    
    context 'with drive access' do
      setup do
        login(:tiger)
      end
      
      should 'return a link to edit on node_actions' do
        assert_match %Q{a[@href='/nodes/#{subject.zip}/versions/0/edit']}, node_actions(subject, :actions => :all)
      end
    
      should 'return a link to drive on node_actions' do
        assert_match %Q{a[@href='/nodes/#{subject.zip}/edit']}, node_actions(subject, :actions => :all)
      end
      
      context 'on a redaction' do
        setup do
          subject.update_attributes(:title => 'wu')
        end
          
        should 'return propose link on node_actions' do
          assert_match %Q{a[@href='/nodes/#{subject.zip}/versions/0/propose]}, node_actions(subject, :actions => :all)
        end
        
        should 'return publish link on node_actions' do
          assert_match %Q{a[@href='/nodes/#{subject.zip}/versions/0/publish]}, node_actions(subject, :actions => :all)
        end
      end
      
      context 'on a proposition' do
        setup do
          subject.update_attributes(:title => 'wu')
          subject.propose
        end
          
        should 'return refuse link on node_actions' do
          assert_match %Q{a[@href='/nodes/#{subject.zip}/versions/0/refuse]}, node_actions(subject, :actions => :all)
        end
        
        should 'return publish link on node_actions' do
          assert_match %Q{a[@href='/nodes/#{subject.zip}/versions/0/publish]}, node_actions(subject, :actions => :all)
        end
      end
      
      context 'on a new node' do
        subject do
          secure!(Page) { Page.new(:title => 'hello', :parent_id => nodes_id(:zena)) }
        end
        
        should 'return an empty string on node_actions' do
          assert_equal '', node_actions(subject, :actions => :all)
        end
      end
    end
  end # With a logged in user
end