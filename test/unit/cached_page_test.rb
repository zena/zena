require File.dirname(__FILE__) + '/../test_helper'
CachedPage
class CachedPage
  def randomize_visited_nodes!
    @expire_with = (200 * rand).to_i.times { ids << (500000 * rand).to_i}
  end
class CachedPageTest < Test::Unit::TestCase
  
  def self.use_transactional_fixtures
    false
  end

#=begin
  # these speed tests take a lot of time, they are disabled when running other tests
  
  # run this once before testing (can take up to several minutes)
  def setup
    super
    for i in 1..10000
      path = Digest::SHA1.hexdigest(rand.to_s)
      ids = []
      (200 * rand).to_i.times { ids << (500000 * rand).to_i}
      expire_with = ".#{ids.join('.')}."
      
      Node.connection.execute "INSERT INTO cached_pages (path, expire_with) VALUES ('#{path}', '#{expire_with}')"
    end
  end
  
  
  def test_speed
    speed_helper('MySQL: FULLTEXT   ') do
      "SELECT id from cached_pages where match(expire_with) against ('#{(5000 * rand).to_i}')"
    end
    speed_helper('MySQL: LIKE syntax') do
      "SELECT id from cached_pages where expire_with LIKE '%.#{(5000 * rand).to_i}.%'"
    end
    Node.connection.execute "DROP INDEX cached_pages_expire_with_index ON cached_pages"
    Node.connection.execute "ALTER TABLE cached_pages type=InnoDB"
    speed_helper('InnoDB:LIKE syntax') do
      "SELECT id from cached_pages where expire_with LIKE '%.#{(5000 * rand).to_i}.%'"
    end
    Node.connection.execute "ALTER TABLE cached_pages ENGINE = MyISAM"
    Node.connection.execute "CREATE FULLTEXT INDEX cached_pages_expire_with_index ON cached_pages (expire_with)"
  end

  def speed_helper(message, count=1000)
    start = Time.now
    i = 0
    count.times do
      puts i if (i % 100) == 0
      i += 1
      Node.connection.execute(yield(i))
    end
    printf "%s: %0.2fs\n", message, (Time.now-start).to_f
  end
#=end
end