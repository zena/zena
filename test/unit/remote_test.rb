require 'test_helper'

class RemoteTest < Zena::Integration::TestCase
  context 'With a remote application' do
    setup do
      test_site(:zena)
      init_test_connection!
      @app = Zena::Remote.connect('http://test.host:3000', 'mytoken')
      @app.send(:include, Zena::Remote::Mock::Connection)
      @app.logger = Node.logger
      @app.message_logger = Node.logger
    end

    context 'and a remote class' do
      subject do
        @app['Tag']
      end

      should 'return a Klass instance' do
        assert_kind_of Zena::Remote::Klass, subject
      end

      context 'creating nodes' do
        should 'create nodes of the correct type' do
          assert_difference('Node.count', 1) do
            node = subject.create(:title => 'Banana', :parent_id => nodes_zip(:cleanWater))
            remote = remote_node(node)
            assert_equal 'Tag', remote.klass
            assert_equal 'Banana', remote.title
          end
        end

        should 'respond to new' do
          node = subject.new(:title => 'Banana', :parent_id => nodes_zip(:cleanWater))
          assert_difference('Node.count', 1) do
            node.save
          end
          remote = remote_node(node)
          assert_equal 'Tag', remote.klass
          assert_equal 'Banana', remote.title
        end
      end # creating nodes

      context 'finding nodes' do
        should 'find with first' do
          assert_equal 'Art', subject.first.title
        end

        should 'find with all' do
          assert_equal ["Art", "News list", "Top menu"], subject.all.map(&:title)
        end

        should 'find with filters' do
          assert_equal ['Art'], subject.all(:title => 'art').map(&:title)
        end

        should 'find with qb filters' do
          assert_equal ['News list'], subject.all('title like "%w%"').map(&:title)
        end
      end # finding nodes

      context 'getting Klass attributes' do
        should 'return list of properties' do
          # TODO
          print 'P'
          #assert_equal {}, subject.properties
        end
      end # getting Klass attributes

    end # and a remote class


    # ================================ Create
    context 'creating' do
      context 'a node with the connection' do
        subject do
          @app.create(:class => 'Post', :title => 'Lady Madonna', :parent_id => nodes_zip(:cleanWater))
        end

        should 'create a new remote node' do
          assert_difference('Node.count', 1) do
            subject
          end
        end
        
        should 'return node zip as id' do
          subject
          last = Node.find(:first, :order => 'id desc')
          assert_equal last.zip, subject.id
        end

        should 'use attributes to create node' do
          node = remote_node(subject.id)
          assert_equal 'Lady Madonna', node.title
          assert_equal nodes_id(:cleanWater), node.parent_id
          assert_equal 'Post', node.klass
        end

        context 'with errors' do
          subject do
            @app.create(:class => 'Post', :title => 'Lady Madonna', :parent_id => 9999)
          end

          should 'return a new record with errors' do
            assert subject.new_record?
            assert subject.errors
          end
        end # with errors


        context 'by using a remote node as parent' do
          subject do
            @app.create(:class => 'Post', :title => 'Lady Madonna', :parent => @app.find(nodes_zip(:cleanWater)))
          end

          should 'use attributes to create node' do
            node = remote_node(subject.id)
            assert_equal 'Lady Madonna', node.title
            assert_equal nodes_id(:cleanWater), node.parent_id
            assert_equal 'Post', node.klass
          end
        end # by using a remote node as parent

      end # a node with the connection
    end # creating

    # ================================ Read
    context 'finding' do

      context 'root node with root' do
        subject do
          @app.root
        end

        should 'find root node with root' do
          assert_equal nodes_zip(:zena), subject.id
        end
      end # root node with root


      context 'nodes with qb' do
        subject do
          # default is 'in site'
          @app.find(:all, 'images')
        end

        should 'find through query builder' do
          assert_equal 4, subject.size
        end

        should 'instanciate results as remote nodes' do
          assert_kind_of Zena::Remote::Node, subject.first
        end
      end # finding nodes with qb

      context 'nodes without specifying count' do
        should 'return an array' do
          assert_kind_of Array, @app.find('images')
          assert_equal 4, @app.find('image').size
        end

        should 'return an array for singular queries' do
          assert_kind_of Array, @app.find('image')
          assert_equal 4, @app.find('image').size
        end
      end # finding nodes without specifying count

      context 'nodes by using all' do
        should 'return an array' do
          assert_kind_of Array, @app.all('images')
          assert_equal 4, @app.all('image').size
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

      context 'nodes by using first' do
        should 'return an instance' do
          assert_kind_of Zena::Remote::Node, @app.first('images')
        end

        context 'with an id' do
          should 'return an instance' do
            assert_kind_of Zena::Remote::Node, @app.first(nodes_zip(:lake_jpg))
          end
        end # with an id
      end # finding nodes by using first

      context 'node count with qb' do
        subject do
          @app.find(:count, 'images')
        end

        should 'find through query builder' do
          assert_equal 4, subject
        end
      end

      context 'node count by using count' do
        subject do
          @app.count('images')
        end

        should 'find through query builder' do
          assert_equal 4, subject
        end
      end

      context 'nodes with search' do
        subject do
          @app.search('la')
        end

        should 'find through fulltext search' do
          assert_equal ["The lake we love", "it's a lake"], subject.map(&:title)
        end
      end
    end # finding

    context 'paginating results' do
      subject do
        @app.all('pages order by title asc', :page => 2, :per_page => 3)
      end

      should 'paginate' do
        assert_equal ["Collections", "crocodiles", "Default skin"], subject.map(&:title)
      end
    end # paginating results

    context 'and a found remote node' do
      subject do
        @app.first('image where title like "%la%"')
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
        assert_equal ["crocodiles", "Keeping things clean !", "Nice Bananas", "status title"], subject.project.pages.map(&:title)
      end

      should 'map missing attributes as queries' do
        assert_equal "crocodiles", subject.project.page.title
        assert_equal ["crocodiles",
         "it's a lake",
         "Keeping things clean !",
         "The lake we love",
         "Nice Bananas",
         "parc opening",
         "status title",
         "water"], subject.parent.nodes.map(&:title)
      end
    end # and a found remote node

    # ================================ Update
    context 'updating a node' do
      subject do
        @app.first(nodes_zip(:status))
      end

      context 'with changed attributes' do
        should 'update remote attributes' do
          subject.title = 'Shalom'
          assert subject.save
          assert_equal 'Shalom', nodes(:status).title
        end

        should 'with update attributes' do
          assert subject.update_attributes(:title => 'Shalom')
          assert_equal 'Shalom', nodes(:status).title
        end
      end # a node with the connection

      context 'with a new relation' do
        subject do
          @app.first(nodes_zip(:lion))
        end

        should 'create link' do
          tag = @app['Tag'].first

          assert_difference('Link.count', 1) do
            subject.set_tag = [tag]
            subject.save
          end

          assert_equal subject.id, tag.first("tagged where title = 'Panthera Leo Verneyi'").id
        end
      end # with a new relation

    end # updating a node

    context 'mass updating' do
      subject do
        @app.update("images", :summary => 'porn')
      end

      should 'update all nodes' do
        subject
        login(:tiger) # user with 'mytoken'
        secure(Image) do
          Image.all.each do |img|
            assert_equal 'porn', img.summary
          end
        end
      end
    end # mass updating


    # ================================ Delete
    context 'deleting' do
      context 'an existing remote node' do
        subject do
          @app.find(nodes_zip(:news))
        end

        should 'remove remote object from the database' do
          assert_difference('Node.count', -1) do
            assert subject.destroy
          end
        end
      end # an existing remote node
    end # deleting


    context 'mass deleting' do
      subject do
        @app.destroy("images")
      end

      should 'delete all nodes' do
        assert_difference('Node.count', -4) do
          subject
        end

        login(:tiger) # user with 'mytoken'
        secure(Image) do
          assert_equal [], Image.all
        end
      end
    end # mass deleting

    context 'bad requests' do
      subject do
        @app.all('foos')
      end

      should 'return an hash with error' do
        assert_equal [], subject
      end
    end # bad requests

  end # With a remote application

  private
    def remote_node(obj_or_id)
      if obj_or_id.kind_of?(Fixnum)
        Node.find_by_zip_and_site_id(obj_or_id, current_site.id)
      elsif obj_or_id.kind_of?(Zena::Remote::Node)
        Node.find_by_zip_and_site_id(obj_or_id.id, current_site.id)
      else
        nil
      end
    end
end
