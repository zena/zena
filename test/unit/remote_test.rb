require 'test_helper'

class RemoteTest < Zena::Integration::TestCase
  context 'With a remote application' do
    setup do
      test_site(:zena)
      init_test_connection!
      @app = Zena::Remote.connect('http://test.host:3000', 'mytoken')
      @app.send(:include, Zena::Remote::Mock::Connection)
    end

    context 'finding nodes with qb' do
      subject do
        @app.find(:all, 'images in site')
      end

      should 'find through query builder' do
        assert_equal 4, subject.size
      end

      should 'instanciate results as remote nodes' do
        assert_kind_of Zena::Remote::Node, subject.first
      end
    end # finding nodes with qb

    context 'finding nodes without specifying count' do
      should 'return an array' do
        assert_kind_of Array, @app.find('images in site')
        assert_equal 4, @app.find('image in site').size
      end

      should 'return an array for singular queries' do
        assert_kind_of Array, @app.find('image in site')
        assert_equal 4, @app.find('image in site').size
      end
    end # finding nodes without specifying count

    context 'finding nodes by using all' do
      should 'return an array' do
        assert_kind_of Array, @app.all('images in site')
        assert_equal 4, @app.all('image in site').size
      end

      should 'return an array for singular queries' do
        assert_kind_of Array, @app.all('image in site')
        assert_equal 4, @app.all('image in site').size
      end

      context 'with a hash' do
        should 'find nodes' do
          assert_equal ["bird"], @app.all(:title => 'bird').map(&:title)
        end
      end # with a hash

    end # finding nodes by using all

    context 'finding nodes by using first' do
      should 'return an instance' do
        assert_kind_of Zena::Remote::Node, @app.first('images in site')
      end

      context 'with an id' do
        should 'return an instance' do
          assert_kind_of Zena::Remote::Node, @app.first(nodes_zip(:lake_jpg))
        end
      end # with an id
    end # finding nodes by using first

    context 'finding node count with qb' do
      subject do
        @app.find(:count, 'images in site')
      end

      should 'find through query builder' do
        assert_equal 4, subject
      end
    end

    context 'finding node count by using count' do
      subject do
        @app.count('images in site')
      end

      should 'find through query builder' do
        assert_equal 4, subject
      end
    end

    context 'finding nodes with search' do
      subject do
        @app.search('la')
      end

      should 'find through fulltext search' do
        assert_equal ["The lake we love", "it's a lake"], subject.map(&:title)
      end
    end


    context 'paginating results' do
      subject do
        @app.all('pages in site order by node_name asc', :page => 2, :per_page => 3)
      end

      should 'paginate' do
        assert_equal ["Collections", "crocodiles", "Default skin"], subject.map(&:title)
      end
    end # paginating results


    context 'and a found remote node' do
      subject do
        @app.first('image where title like "%la%" in site')
      end

      should 'return attributes from method calls' do
        assert_equal "it's a lake", subject.title
      end

      should 'contain id' do
        assert_equal nodes_zip(:lake_jpg), subject.id
      end

      should 'enable further search queries' do
        assert_equal 'Clean Water project', subject.first('icon_for').title
      end

      should 'map missing attributes as first queries' do
        assert_equal 'Clean Water project', subject.icon_for.title
        assert_equal ["Nice Bananas", "crocodiles", "status title", "Keeping things clean !"], subject.project.pages.map(&:title)
      end

      should 'map missing attributes as all queries' do
        assert_equal "Nice Bananas", subject.project.page.title
      end
    end # and a found remote node

  end # With a remote application
end
