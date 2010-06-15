require 'test_helper'

class RefactorTest < Zena::View::TestCase
  def setup
    login(:anon)
    visiting(:status)
  end

  def test_render_to_string
    assert_equal 'stupid test 25',  render_to_string(:inline=>'stupid <%= "test" %> <%= 5*5 %>')
  end

  def test_fsize
    assert_equal '29 Kb', fsize(29279)
    assert_equal '502 Kb', fsize(513877)
    assert_equal '5.2 Mb', fsize(5480809)
    assert_equal '450.1 Mb', fsize(471990272)
    assert_equal '2.35 Gb', fsize(2518908928)
  end

  def test_rnd
    assert ((Time.now.to_i-1 <= rnd) && (rnd <= Time.now.to_i+2))
  end

  def test_traductions
    visitor.lang = 'en'
    # we must initialize an url for url_rewriting in 'traductions'
    @controller.instance_eval { @url = ActionController::UrlRewriter.new( @request, {:controller=>'nodes', :action=>'index'} ) }
    @node = secure!(Node) { Node.find(nodes_id(:status)) } # en,fr
    trad = traductions
    assert_equal 2, trad.size
    assert_match %r{class='current'.*href="/en}, trad[0]
    assert_no_match %r{class='current'}, trad[1]
    @node = secure!(Node) { Node.find(nodes_id(:cleanWater)) } #  en
    trad = traductions
    assert_equal 1, trad.size
  end
end