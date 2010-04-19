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
        should 'return a Contact' do
          assert_kind_of Contact, subject.author
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


      def test_edited
        v = versions(:zena_en)
        assert !v.edited?
        v.status = 999
        assert !v.edited?
        v.title = 'new title'
        assert v.edited?
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
          @node = secure!(Page) { Page.create(:v_lang => 'io', :parent_id => nodes_id(:status), :name => 'hello')}
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
          @node = secure!(Page) { Page.create(:v_lang => 'de', :parent_id => nodes_id(:status), :name => 'hello')}
        end

        should 'create a single version' do
          assert_difference('Version.count', 1) do
            subject
          end
        end

        should 'change visitor lang' do
          assert_equal 'en', visitor.lang
          subject
          assert_equal 'de', visitor.lang
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
                assert subject.update_attributes(:v_lang => 'fr')
              end
              assert_equal 'fr', subject.v_lang
            end
          end
        end
      end
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

  context 'A visitor with write access on a redaction with dyn attributes' do
    setup do
      login(:tiger)
      node = secure(Node) { nodes(:nature) }
      node.update_attributes(:d_foo => 'bar')
      @node = secure(Node) { nodes(:nature) } # reload
    end

    should 'see dyn attribute' do
      assert_equal 'bar', @node.version.prop['foo']
    end

    should 'see be able to update dyn attribute' do
      assert @node.version.dyn.would_edit?('foo' => 'max')
      assert @node.update_attributes(:d_foo => 'max')
      @node = secure(Node) { nodes(:nature) }
      assert_equal 'max', @node.version.prop['foo']
    end
  end


  def test_dynamic_attributes
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    assert_nothing_raised { version.prop['zucchini'] = 'courgettes' }
    assert_nothing_raised { version.dyn_attributes = {'zucchini' => 'courgettes' }}
    assert_equal 'courgettes', version.prop['zucchini']
    assert node.save

    node = secure!(Node) { nodes(:status) }
    version = node.version
    assert_equal 'courgettes', version.prop['zucchini']
  end

  def test_clone
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    assert node.update_attributes(:d_whatever => 'no idea')
    assert_equal 'no idea', node.version.prop['whatever']
    version1_id = node.version[:id]
    assert node.publish
    version1_publish_from = node.version.publish_from

    node = secure!(Node) { nodes(:status) }
    assert node.update_attributes(:d_other => 'funny')
    version2_id = node.version[:id]
    assert_not_equal version1_id, version2_id
    assert_equal 'no idea', node.version.prop['whatever']
    assert_equal 'funny', node.version.prop['other']
    assert_equal version1_publish_from, node.version.publish_from
  end
end
