require File.dirname(__FILE__) + '/../spec_helper'

describe VersionsController do
  
  it { should route(:get, "/nodes/11/versions/0/edit",    :controller => :versions, :action => :edit, :node_id => 11, :id => 0)    }
  it { should route(:get, "/nodes/11/versions/2/preview", :controller => :versions, :action => :preview, :node_id => 11, :id => 2)    }
  
  it "should publish the previous version" do
    # TODO: login, etc
  end
end
