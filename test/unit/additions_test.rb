require File.dirname(__FILE__) + '/../test_helper'
class AdditionsTest < ActiveSupport::TestCase
  include Zena::Test::Unit
  def setup; login(:anon); end

  def setup
    super
  end
  
  def test_zip_fixtures
    assert_equal zips_zip(:zena), Node.connection.execute("select zip from zips where site_id = #{sites_id(:zena)}").fetch_row[0].to_i
  end
  
  def test_fetch_ids
    ids  = [:zena, :people, :ant].map{|r| nodes_id(r)}
    zips = [:zena, :people, :ant].map{|r| nodes_zip(r)}
    assert_list_equal ids, Node.fetch_ids("SELECT id FROM nodes WHERE id IN (#{ids.join(',')})")
    assert_list_equal ids, Node.fetch_ids("id IN (#{ids.join(',')})")
    assert_list_equal zips, Node.fetch_ids("id IN (#{ids.join(',')})", :zip)
  end
  
  def test_fetch_list
    ids  = [:zena, :people, :ant].map{|r| nodes_id(r)}
    
    assert_list_equal [{:id=>nodes_id(:zena), :name=>"zena"},{:id=>nodes_id(:people), :name=>"people"}, {:id=>nodes_id(:ant), :name=>"ant"}], Node.fetch_list("SELECT id, name FROM nodes WHERE id IN (#{ids.join(',')})", :id, :name)
    
    assert_list_equal [{:id=>nodes_id(:zena), :name=>"zena"},{:id=>nodes_id(:people), :name=>"people"}, {:id=>nodes_id(:ant), :name=>"ant"}], Node.fetch_list("id IN (#{ids.join(',')})", :id, :name)
    
    assert_list_equal [{:zip=>nodes_zip(:zena), :rgroup_id=>groups_id(:public)},{:zip=>nodes_zip(:people), :rgroup_id=>groups_id(:public)}, {:zip=>nodes_zip(:ant), :rgroup_id=>"0"}], Node.fetch_list("id IN (#{ids.join(',')})", :zip, :rgroup_id)
  end
  
  def test_next_zip
    assert_raise(Zena::BadConfiguration) { Node.next_zip(88) }
    assert_equal zips_zip(:zena ) + 1, Node.next_zip(sites_id(:zena))
    assert_equal zips_zip(:ocean) + 1, Node.next_zip(sites_id(:ocean))
    assert_equal zips_zip(:zena ) + 2, Node.next_zip(sites_id(:zena))
  end
  
  def test_next_zip_rollback
    assert_raise(Zena::BadConfiguration) { Node.next_zip(88) }
    assert_equal zips_zip(:zena ) + 1, Node.next_zip(sites_id(:zena))
    assert_equal zips_zip(:ocean) + 1, Node.next_zip(sites_id(:ocean))
    assert_equal zips_zip(:zena ) + 2, Node.next_zip(sites_id(:zena))
  end
  
  def test_fetch_attribute
    assert_equal "water", Node.fetch_attribute(:name, "id = #{nodes_id(:water_pdf)}")
    assert_nil Node.fetch_attribute(:name, "0")
  end
  
  private
    def assert_list_equal(l1, l2)
      if l1[0].kind_of?(Hash)
        [l1,l2].each do |l|
          l.each do |h|
            h.each do |k,v|
              h[k] = v.to_s
            end
          end
        end
        l1.each do |h|
          assert l2.include?(h)
        end
        assert_equal l1.uniq.size, l2.uniq.size
      else
        assert_equal l1.map{|v| v.to_s}.sort, l2.map{|v| v.to_s}.sort
      end
    end
end
