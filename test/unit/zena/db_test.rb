require 'test_helper'
class DbTest < Zena::Unit::TestCase
  def test_db_NOW_in_sync
    assert res = Zena::Db.fetch_attribute("SELECT (#{Zena::Db::NOW} - #{Zena::Db.quote_date(Time.now)})")
    assert_equal 0.0, res.to_f
  end

  def test_zip_fixtures
    assert_equal zips_zip(:zena), Zena::Db.fetch_attribute("select zip from zips where site_id = #{sites_id(:zena)}").to_i
  end

  def test_fetch_ids
    ids  = [:zena, :people, :ant].map{|r| nodes_id(r)}
    zips = [:zena, :people, :ant].map{|r| nodes_zip(r)}
    assert_list_equal ids, Zena::Db.fetch_ids("SELECT id FROM nodes WHERE id IN (#{ids.join(',')})")
    assert_list_equal ids, Zena::Db.fetch_ids("SELECT id FROM nodes WHERE id IN (#{ids.join(',')})")
    assert_list_equal zips, Zena::Db.fetch_ids("SELECT zip FROM nodes WHERE id IN (#{ids.join(',')})", 'zip')
  end

  def test_next_zip
    assert_raise(Zena::BadConfiguration) { Zena::Db.next_zip(88) }
    assert_equal zips_zip(:zena ) + 1, Zena::Db.next_zip(sites_id(:zena))
    assert_equal zips_zip(:ocean) + 1, Zena::Db.next_zip(sites_id(:ocean))
    assert_equal zips_zip(:zena ) + 2, Zena::Db.next_zip(sites_id(:zena))
  end

  def test_insensitive_find
    assert_equal nodes_zip(:status), secure(Node) { Zena::Db.insensitive_find(Node, :first, :node_name => 'sTatuS')}.zip
  end
  
  def test_next_zip_rollback
    assert_raise(Zena::BadConfiguration) { Zena::Db.next_zip(88) }
    assert_equal zips_zip(:zena ) + 1, Zena::Db.next_zip(sites_id(:zena))
    assert_equal zips_zip(:ocean) + 1, Zena::Db.next_zip(sites_id(:ocean))
    assert_equal zips_zip(:zena ) + 2, Zena::Db.next_zip(sites_id(:zena))
  end

  def test_fetch_row
    assert_equal "water", Zena::Db.fetch_attribute("SELECT node_name FROM nodes WHERE id = #{nodes_id(:water_pdf)}")
    assert_nil Zena::Db.fetch_attribute("SELECT node_name FROM nodes WHERE #{Zena::Db::FALSE}")
  end

  def test_fetch_attributes
    assert_equal [{"node_name"=>"secret", "zip"=>"19"},
     {"node_name"=>"status", "zip"=>"22"},
     {"node_name"=>"strange", "zip"=>"36"},
     {"node_name"=>"skins", "zip"=>"51"},
     {"node_name"=>"style", "zip"=>"53"}], Zena::Db.fetch_attributes(['zip','node_name'], 'nodes', "node_name like 's%' and site_id = #{sites_id(:zena)} ORDER BY zip")
  end

  context 'A node that needs attribute changes without validations or side effects' do
    setup do
      login(:anon)
      @node = secure!(Node) { nodes(:status) }
    end

    should 'not change updated_at date' do
      old_updated_at = @node.updated_at
      Zena::Db.set_attribute(@node, :node_name, 'flop')
      @node = secure!(Node) { nodes(:status) } # reload
      assert_equal old_updated_at, @node.updated_at
    end

    should 'set attribute in node' do
      Zena::Db.set_attribute(@node, :node_name, 'flop')
      assert_equal 'flop', @node.node_name
    end

    should 'not mark as dirty' do
      Zena::Db.set_attribute(@node, :node_name, 'flop')
      assert !@node.changed?
    end

    should 'set attribute in db' do
      Zena::Db.set_attribute(@node, :node_name, 'flop')
      @node = secure!(Node) { nodes(:status) } # reload
      assert_equal 'flop', @node.node_name
    end

    should 'set a time' do
      Zena::Db.set_attribute(@node, :publish_from, Time.gm(2009,10,1))
      @node = secure!(Node) { nodes(:status) } # reload
      assert_equal Time.gm(2009,10,1), @node.publish_from
    end

    should 'set an integer' do
      Zena::Db.set_attribute(@node.version, :status, Zena::Status[:rep])
      version = secure!(Version) { Version.find(@node.version.id) } # reload
      assert_equal Zena::Status[:rep], version.status
    end
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
