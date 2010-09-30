require 'test_helper'
class VersionTest < Zena::Unit::TestCase
  context 'With a logged in visitor' do
    setup do
      login(:tiger)
    end

    context 'a version' do
      subject do
        versions(:status_en)
      end

      context 'receiving author' do
        should 'return a Node' do
          assert_kind_of Node, subject.author
        end

        should 'return the contact node of the author' do
          assert_equal nodes_id(:ant), subject.author[:id]
        end
      end # receiving author

      # Workflow testing....
      should 'ignore workflow attributes on edited' do
        subject.attributes = {'title' => 'status title', 'publish_from' => Time.now}
        assert subject.changed?
        assert !subject.edited?
      end

      should 'use properties on edited' do
        subject.attributes = {'title' => 'Foo title'}
        assert subject.changed?
        assert subject.edited?
      end

      should 'not be marked as edited' do
        assert !subject.edited?
      end

      should 'not be marked as edited on status change' do
        subject.status = 999
        assert !subject.edited?
      end

      should 'be marked as edited on node property change' do
        subject.node.title = 'new title'
        assert subject.edited?
      end
    end # a version


    context 'a redaction' do
      subject do
        versions(:opening_red_fr)
      end
    end # a redaction

    context 'on node creation' do
      context 'setting an invalid v_lang' do
        setup do
          @node = secure!(Page) { Page.create(:v_lang => 'io', :parent_id => nodes_id(:status), :title => 'hello')}
        end

        should 'not create record if lang is not allowed' do
          assert @node.new_record?
        end

        should 'return an error on v_lang' do
          assert @node.errors[:v_lang].any?
        end
      end

      context 'setting a valid v_lang' do
        subject do
          @node = secure!(Page) { Page.create(:v_lang => 'de', :parent_id => nodes_id(:status), :title => 'hello')}
        end

        should 'create a single version' do
          assert_difference('Version.count', 1) do
            subject
          end
        end

        should 'set version lang' do
          assert_equal 'de', subject.version.lang
        end
      end
    end # setting v_lang

    context 'updating a version' do
      setup do
        @node = secure!(Node) { nodes(:status) }
      end

      subject do
        @node.version
      end

      should 'not allow setting node_id' do
        subject.update_attributes(:node_id => nodes_id(:lake))
        assert_equal nodes_id(:status), subject.node_id
      end

      should 'not allow setting attachment_id' do
        subject.update_attributes(:attachment_id => attachments_id(:bird_jpg_en))
        assert_nil subject.attachment_id
      end

      should 'not allow setting site_id' do
        subject.update_attributes(:site_id => sites_id(:ocean))
        assert_equal sites_id(:zena), subject.site_id
      end

      should 'not allow setting number' do
        subject.update_attributes(:number => 5)
        assert_equal 1, subject.number
      end

      context 'with a locale and time_zone' do
        setup do
          I18n.locale = 'fr'
          visitor.time_zone = 'Asia/Jakarta'
        end

        should 'parse publish_from date depending on time_zone' do
          subject.update_attributes('publish_from' => '9-9-2009 15:17')
          assert_equal Time.utc(2009,9,9,8,17), subject.publish_from
        end
      end
    end # updating a version

    context 'updating a node' do
      subject do
        secure!(Node) { nodes(:ant) }
      end

      should 'increase version number' do
        assert_difference('subject.version.number', 1) do
          subject.update_attributes(:first_name => 'John')
        end
      end

      should 'create a new version' do
        assert_difference('Version.count', 1) do
          subject.update_attributes(:first_name => 'Foobar')
        end
      end

      context 'in redit time' do
        setup do
          subject.update_attributes(:first_name => 'Annette')
        end

        context 'in the same v_lang' do
          should 'not create a new version' do
            assert_difference('Version.count', 0) do
              subject.update_attributes(:first_name => 'Bug')
            end
          end

          should 'create a new version if backup required' do
            assert_difference('Version.count', 1) do
              assert subject.update_attributes('first_name'=>'Eric', 'v_backup' => 'true')
            end
          end
        end

        context 'with a new v_lang' do
          should 'create a new redaction' do
            assert_difference('subject.versions.count', 1) do
              assert_difference('Version.count', 1) do
                assert subject.update_attributes(:v_lang => 'de')
              end
              assert_equal 'de', subject.v_lang
            end
          end
        end
      end # in redit time
    end # updating a node
  end # With a logged in visitor

  context 'A new version' do
    should 'not allow setting node_id' do
      version = Version.new(:node_id => 1234)
      assert_nil version.node_id
    end

    should 'not allow setting attachment_id' do
      version = Version.new(:attachment_id => attachments_id(:bird_jpg_en))
      assert_nil version.attachment_id
    end

    should 'not allow setting site_id' do
      version = Version.new(:site_id => sites_id(:ocean))
      assert_nil version.site_id
    end

    should 'not allow setting number' do
      version = Version.new(:number => 5)
      assert_equal 1, version.number
    end

    should 'set site_id on save' do
      version = Version.new(:status => Zena::Status[:red])
      version.node = secure!(Node) { nodes(:status) }
      assert version.save
      assert_equal sites_id(:zena), version.site_id
    end

    should 'not save if node is not set' do
      version = Version.new(:status => Zena::Status[:red])
      assert !version.save
      assert_equal "can't be blank", version.errors[:node]
    end

    should 'mark as edited' do
      assert subject.edited?
    end
  end # A new version
end
