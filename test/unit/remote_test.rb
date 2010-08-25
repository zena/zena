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

    context 'finding node count with qb' do
      subject do
        @app.find(:count, 'images in site')
      end

      should 'find through query builder' do
        assert_equal 4, subject
      end
    end # finding nodes with qb

    context 'and a found remote node' do
      subject do
        @app.find(:first, 'images where title like "bi%" in site')
      end

      should 'respond to title' do
        assert_equal 'bird', subject.title
      end
    end # and a found remote node

  end # With a remote application
end
