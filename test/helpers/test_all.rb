require File.join(File.dirname(__FILE__), 'testhelp')

class HelperTest
  testfile :relations, :basic
  def test_single
    do_test('relations', 'date_select')
  end
  
  def test_relations_updated_today
    Node.connection.execute "UPDATE nodes SET updated_at = now() WHERE id IN (12, 23);" # status, art
    do_test('relations', 'node_id')
  end
  
  def test_relations_upcoming_events
    Node.connection.execute "UPDATE nodes SET log_at = ADDDATE(curdate(), interval 1 week) WHERE id IN (2);" # people
    do_test('relations', 'upcoming_events')
  end
  
  def test_relations_in_7_days
    Node.connection.execute "UPDATE nodes SET log_at = now() WHERE id IN (12, 23);" # status, art
    Node.connection.execute "UPDATE nodes SET log_at = ADDDATE(curdate(), interval 6 day) WHERE id IN (8, 11);" # projects, cleanWater
    Node.connection.execute "UPDATE nodes SET log_at = ADDDATE(curdate(), interval 10 day) WHERE id IN (2);" # people
    do_test('relations', 'in_7_days')
  end
  
  def test_relations_logged_7_days_ago
    Node.connection.execute "UPDATE nodes SET log_at = now() WHERE id IN (12, 23);" # status, art
    Node.connection.execute "UPDATE nodes SET log_at = ADDDATE(curdate(), interval -6 day) WHERE id IN (8, 11);" # projects, cleanWater
    Node.connection.execute "UPDATE nodes SET log_at = ADDDATE(curdate(), interval -10 day) WHERE id IN (2);" # people
    do_test('relations', 'logged_7_days_ago')
  end
  
  def test_relations_around_7_days
    Node.connection.execute "UPDATE nodes SET log_at = now() WHERE id IN (12);" # status
    Node.connection.execute "UPDATE nodes SET log_at = ADDDATE(curdate(), interval 5 day) WHERE id IN (23);" # art
    Node.connection.execute "UPDATE nodes SET log_at = ADDDATE(curdate(), interval -6 day) WHERE id IN (8, 11);" # projects, cleanWater
    Node.connection.execute "UPDATE nodes SET log_at = ADDDATE(curdate(), interval -10 day) WHERE id IN (2);" # people
    do_test('relations', 'around_7_days')
  end
  
  def test_relations_this_week
    if Time.now.strftime('%u').to_i < 3
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval -5 day) WHERE id IN (2);" # people
      # objs in the future
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval 2 day) WHERE id IN (23);" # status, art
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval 1 day) WHERE id IN (8);" # projects, cleanWater
    else
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval 5 day) WHERE id IN (2);" # people
      # objs in the past
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval -2 day) WHERE id IN (23);" # status, art
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval -1 day) WHERE id IN (8);" # projects, cleanWater
    end  
    do_test('relations', 'this_week')    
  end
  
  def test_relations_this_month
    if Time.now.strftime('%d').to_i < 15
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval -20 day) WHERE id IN (2);" # people
      # objs in the future
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval 12 day) WHERE id IN (23);" # status, art
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval 5 day) WHERE id IN (8);" # projects, cleanWater
    else
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval 20 day) WHERE id IN (2);" # people
      # objs in the past
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval -12 day) WHERE id IN (23);" # status, art
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval -5 day) WHERE id IN (8);" # projects, cleanWater
    end  
    do_test('relations', 'this_month')    
  end
  
  def test_relations_this_year
    if Time.now.strftime('%m').to_i < 6
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval -8 month) WHERE id IN (2);" # people
      # objs in the future
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval 2 month) WHERE id IN (23);" # status, art
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval 1 month) WHERE id IN (8);" # projects, cleanWater
    else
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval 8 month) WHERE id IN (2);" # people
      # objs in the past
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval -2 month) WHERE id IN (23);" # status, art
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval -1 month) WHERE id IN (8);" # projects, cleanWater
    end  
    do_test('relations', 'this_year')    
  end
  
  make_tests
end