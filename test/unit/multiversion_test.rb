require 'test_helper'

class MultiVersionTest < Zena::Unit::TestCase

  def defaults
    { :name => 'hello',
      :parent_id => nodes_id(:zena) }
  end

  # =========== FIND VERSION TESTS =============

  context 'A visitor without write access' do
    setup do
      login(:anon)
    end

    should 'see a publication in her language' do
      node = secure!(Node) { nodes(:opening) }
      assert_equal versions_id(:opening_en), node.version.id
    end

    should 'see a publication in the selected language' do
      visitor.lang = 'fr'
      node = secure!(Node) { nodes(:opening) }
      assert_equal versions_id(:opening_fr), node.version.id
    end

    should 'see a publication in the reference lang if there are none for the current language' do
      visitor.lang = 'de'
      node = secure!(Node) { nodes(:opening) }
      assert_equal 'fr', node.ref_lang
      assert_equal versions_id(:opening_fr), node.version.id
    end

    should 'see the list of editions' do
      # published versions
      node = secure!(Node) { nodes(:opening)  }
      assert_equal 2, node.editions.count
    end

    context 'when there is only a redaction for the current language' do
      setup do
        login(:tiger)
        version = secure!(Version) { versions(:opening_fr) }
        node = version.node
        assert node.destroy_version
        assert_equal [:opening_red_fr, :opening_en].map{|s| versions_id(s)}.sort, node.versions.map{|v| v.id}.sort
        login(:anon)
      end

      should 'see a default publication' do
        node = secure!(Node) { nodes(:opening) }
        assert_equal versions_id(:opening_en), node.version.id
      end
    end
  end # A visitor without write access

  context 'A visitor with write access' do
    setup do
      login(:ant)
    end

    should 'see a publication in the selected language' do
      visitor.lang = 'en'
      node = secure!(Node) { nodes(:opening) }
      assert_equal versions_id(:opening_en), node.version.id
    end

    should 'see a redaction in her language' do
      node = secure!(Node) { nodes(:opening) }
      assert_equal versions_id(:opening_red_fr), node.version.id
    end

    should 'see what he would see in the reference lang if there is nothing for the current language' do
      visitor.lang = 'de'
      node = secure!(Node) { nodes(:opening) }
      assert_equal 'fr', node.ref_lang
      assert_equal versions_id(:opening_red_fr), node.version.id
    end

    context 'in a language not supported' do
      setup do
        login(:tiger)
        version = secure!(Version) { versions(:opening_fr) }
        node = version.node
        assert node.destroy_version
        assert_equal [:opening_red_fr, :opening_en].map{|s| versions_id(s)}.sort, node.versions.map{|v| v.id}.sort
        login(:ant)
      end

      should_eventually 'see any publication if there are none for the current language and the reference language' do
        visitor.lang = 'de'
        node = secure!(Node) { nodes(:opening) }
        assert_equal versions_id(:opening_en), node.version.id
      end
    end

    should 'see a redaction if there are no publications' do
      visitor.lang = 'de'
      node = secure!(Node) { nodes(:crocodiles) }
      assert_equal versions_id(:crocodiles_en), node.version.id
    end

    context 'on a node with replaced versions' do
      setup do
        login(:tiger)
        @node = secure!(Node) { nodes(:proposition) }
      end

      should 'see latest publication' do
        assert_equal versions_id(:proposition_en), @node.version.id
      end
    end # A visitor with write access in a language not supported
  end # A visitor with write access


  # =========== UPDATE VERSION TESTS =============

  context 'A visitor with write access' do

    context 'on a redaction' do

      context 'that she owns' do
        setup do
          login(:tiger)
          visitor.lang = 'fr'
          @node = secure!(Node) { nodes(:opening) }
        end

        should 'see own redaction' do
          # this is only to make sure fixtures are used correctly
          assert_equal Zena::Status[:red], @node.version.status
          assert_equal visitor.id, @node.version.user_id
        end

        should 'not create a new redaction when editing' do
          assert_difference('Version.count', 0) do
            assert @node.update_attributes(:v_title => 'Artificial Intelligence')
          end
        end

        should 'be allowed to propose' do
          assert @node.can_propose?
          assert @node.propose
          assert_equal Zena::Status[:prop], @node.version.status
        end

        should 'be allowed to remove' do
          assert @node.can_remove?
          assert @node.remove
          assert_equal Zena::Status[:rem], @node.version.status
        end
      end # A visitor with write access on a redaction that she owns

      context 'from another author' do
        setup do
          login(:ant)
          visitor.lang = 'fr'
          @node = secure!(Node) { nodes(:opening) }
        end

        should 'see other author\'s redaction' do
          # this is only to make sure fixtures are used correctly
          assert_equal Zena::Status[:red], @node.version.status
          assert_not_equal visitor.id, @node.version.user_id
        end

        should 'not create a new redaction if all attributes are identical' do
          assert_difference('Version.count', 0) do
            assert @node.update_attributes(:v_title => @node.version.title, :v_text => @node.version.text)
          end
        end

        should 'replace redaction with a new one when updating attributes' do
          old_redaction_id = @node.version.id
          assert_difference('Version.count', 1) do
            assert @node.update_attributes(:v_title => 'Mon idée')
            assert_equal Zena::Status[:red], @node.version.status
          end
          old_redaction = Version.find(old_redaction_id)
          assert_equal Zena::Status[:rep], old_redaction.status
        end

        should 'be allowed to propose' do
          assert @node.can_propose?
          assert @node.propose
          assert_equal Zena::Status[:prop], @node.version.status
        end
      end # A visitor with write access on a redaction from another author
    end # A visitor with write access on a redaction

    # -------------------- ON A PUBLICATION
    context 'on a publication' do
      setup do
        login(:ant)
        @node = secure!(Node) { nodes(:status) }
      end

      should 'see a publication' do
        # this is only to make sure fixtures are used correctly
        assert_equal Zena::Status[:pub], @node.version.status
        assert !@node.new_record?
      end

      should 'be allowed to edit' do
        assert @node.can_edit?
      end

      should 'create a redaction when updating attributes' do
        assert_difference('Version.count', 1) do
          assert @node.update_attributes(:v_title => 'The Technique Of Orchestration')
        end
      end

      should 'be able to write new attributes using nested attributes alias' do
        assert_difference('Version.count', 1) do
          node = secure!(Node) { nodes(:lake) }
          assert node.update_attributes(:v_title => 'Mea Lua', :c_country => 'Brazil')
          node = secure!(Node) { nodes(:lake) } # reload
          assert_equal 'Mea Lua', node.version.title
          assert_equal 'Brazil', node.version.content.country
        end
      end

      should 'be able to create nodes using nested attributes alias' do
        node = secure!(Node) { Node.create(defaults.merge(:v_title => 'Pandeiro')) }
        assert_equal 'Pandeiro', node.version.title
      end

      should 'create a new redaction when setting version_attributes' do
        @node.version_attributes = {'title' => 'labias'}
        assert_equal 'labias', @node.version.title
        assert @node.version.new_record?
        assert_difference('Version.count', 1) do
          assert @node.save
        end
      end

      should 'create versions in the current language' do
        visitor.lang = 'de'
        @node.version_attributes = {'title' => 'Sein und Zeit'}
        assert_equal 'de', @node.version.lang
      end

      should 'not be allowed to propose' do
        assert !@node.can_propose?
        assert !@node.propose # does nothing
      end

      should 'not be allowed to publish' do
        assert !@node.can_publish?
        assert !@node.publish
        assert_equal 'Already published.', @node.errors[:base]
      end

      should 'not be allowed to unpublish' do
        assert !@node.can_remove?
        assert !@node.can_unpublish?
        assert !@node.unpublish
        assert_equal 'You do not have the rights to unpublish.', @node.errors[:base]
      end
    end # A visitor with write access on a publication


    # -------------------- ON A PROPOSITION
    context 'on a proposition' do
      setup do
        login(:ant)
        visitor.lang = 'fr'
        @node = secure!(Node) { nodes(:opening) }
        @node.propose
        @node = secure!(Node) { nodes(:opening) } # reload
      end

      should 'see a proposition.' do
        # this is only to make sure fixtures are used correctly
        assert_equal Zena::Status[:prop], @node.version.status
      end

      should 'not be allowed to update' do
        assert !@node.can_edit?
        assert !@node.update_attributes(:v_title => 'foobar')
        print 'P'
        #assert_equal 'You cannot edit while a proposition is beeing reviewed.', @node.errors[:base]
      end

      should 'not be allowed to propose' do
        assert !@node.can_propose?
        assert !@node.propose
        assert 'Already proposed.', @node.errors[:base]
      end

      should 'not be allowed to publish' do
        assert !@node.can_publish?
        assert !@node.publish
        print 'P'
        #assert_equal 'You do not have the rights to publish.', @node.errors[:base]
      end

      should 'not be allowed to remove' do
        assert !@node.can_remove?
        assert !@node.remove
        assert_equal 'You should refuse the proposition before removing it.', @node.errors[:base]
      end

      should 'not be allowed to refuse' do
        assert !@node.can_refuse?
        assert !@node.refuse
        assert_equal 'You do not have the rights to refuse.', @node.errors[:base]
      end
    end # A visitor with write access on a proposition

  end # A visitor with write access


  context 'A visitor with drive access' do

    context 'on a redaction' do
      setup do
        login(:tiger)
        @node = secure!(Node) { nodes(:crocodiles) }
      end

      should 'see a redaction' do
        # this is only to make sure fixtures are used correctly
        assert_equal Zena::Status[:red], @node.version.status
      end

      should 'be allowed to propose' do
        assert @node.can_propose?
        assert @node.propose
        assert_equal Zena::Status[:prop], @node.version.status
      end

      should 'be allowed to publish' do
        assert @node.can_publish?
        assert @node.publish
        assert_equal Zena::Status[:pub], @node.version.status
      end

      should 'be allowed to remove' do
        assert @node.can_remove?
        assert @node.remove
        assert_equal Zena::Status[:rem], @node.version.status
      end
    end # A visitor with drive access on a redaction

    # -------------------- ON A PUBLICATION
    context 'on a publication' do
      setup do
        login(:tiger)
        @node = secure!(Node) { nodes(:status) }
      end

      should 'see a publication' do
        # this is only to make sure fixtures are used correctly
        assert_equal Zena::Status[:pub], @node.version.status
      end

      should 'not be allowed to propose' do
        assert !@node.can_propose?
        assert !@node.propose
        assert_equal 'This transition is not allowed.', @node.errors[:base]
      end

      should 'not be allowed to publish' do
        assert !@node.can_publish?
        assert !@node.publish
        assert_equal 'Already published.', @node.errors[:base]
      end

      should 'be allowed to unpublish' do
        assert @node.can_unpublish?
        assert @node.unpublish
        assert_equal Zena::Status[:rem], @node.version.status
      end

      should 'see an up-to-date versions list after unpublish' do
        @node = secure!(Node) { nodes(:opening) }
        assert @node.unpublish
        versions = @node.versions
        assert_equal Zena::Status[:rem], versions.detect {|v| v.id == versions_id(:opening_en)}.status
        assert_equal Zena::Status[:pub], versions.detect {|v| v.id == versions_id(:opening_fr)}.status
        assert_equal Zena::Status[:red], versions.detect {|v| v.id == versions_id(:opening_red_fr)}.status
      end

      should 'not be allowed to refuse' do
        assert !@node.can_refuse?
        assert !@node.refuse
        assert_equal 'This transition is not allowed.', @node.errors[:base]
      end

      should_eventually 'replace a redaction when re editing a removed version' do
      end

      should 'not see that she can remove' do
        assert !@node.can_remove?
        assert @node.remove
        assert_equal Zena::Status[:rem], @node.version.status
      end
    end # A visitor with drive access on a publication


    # -------------------- ON A PROPOSITION
    context 'on a proposition' do
      setup do
        login(:tiger)
        visitor.lang = 'fr'
        @node = secure!(Node) { nodes(:opening) }
        @node.propose
        @node = secure!(Node) { nodes(:opening) } # reload
      end

      should 'see a proposition' do
        # this is only to make sure fixtures are used correctly
        assert_equal Zena::Status[:prop], @node.version.status
      end

      should 'not be allowed to propose' do
        assert !@node.can_propose?
        assert !@node.propose
        assert 'Already proposed.', @node.errors[:base]
      end

      should 'be allowed to publish' do
        assert @node.can_publish?
        assert @node.publish
        assert_equal Zena::Status[:pub], @node.version.status
      end

      should 'be allowed to publish by setting status attribute' do
        assert @node.update_attributes(:v_status => Zena::Status[:pub])
        assert_equal Zena::Status[:pub], @node.version.status
      end

      should 'be allowed to publish with a custom date' do
        assert @node.update_attributes(:v_status => Zena::Status[:pub], :v_publish_from => '2007-01-03')
        assert_equal Time.gm(2007,1,3), @node.version.publish_from
      end

      should_eventually 'be allowed to publish and change attributes other then publish_from' do
        assert @node.update_attributes(:v_status => Zena::Status[:pub], :v_title => 'I hack my own !')
        assert_equal 'I hack my own !', @node.version.title
      end

      should 'replace old publication on publish' do
        @node.publish
        assert_equal Zena::Status[:rep], versions(:opening_fr).status
      end

      should 'see an up-to-date versions list after publish' do
        @node.publish
        versions = @node.versions
        assert_equal Zena::Status[:pub], versions.detect {|v| v.id == versions_id(:opening_en)}.status
        assert_equal Zena::Status[:rep], versions.detect {|v| v.id == versions_id(:opening_fr)}.status
        assert_equal Zena::Status[:pub], versions.detect {|v| v.id == versions_id(:opening_red_fr)}.status
      end

      should 'be allowed to refuse' do
        assert @node.can_refuse?
        assert @node.refuse
        assert_equal Zena::Status[:red], @node.version.status
      end

      should 'not be allowed to remove' do
        assert !@node.can_remove?
        assert !@node.remove
        assert_equal 'You should refuse the proposition before removing it.', @node.errors[:base]
      end

      should 'not be allowed to unpublish' do
        assert !@node.can_unpublish?
      end

      context 'from another author' do
        setup do
          login(:lion)
          visitor.lang = 'fr'
          @node = secure!(Node) { nodes(:opening) } # reload
        end

        should 'be allowed to publish with a custom date anterior to the first publication' do
          @node.update_attributes(:v_status => Zena::Status[:pub], :v_publish_from => '1800-01-03')
          assert_equal Time.gm(1800,1,3), @node.version.publish_from
          assert_equal Time.gm(1800,1,3), @node.publish_from
        end

        should 'be allowed to publish with a custom date' do
          assert @node.update_attributes(:v_status => Zena::Status[:pub], :v_publish_from => '2007-01-03')
          assert_equal Time.gm(2007,1,3), @node.version.publish_from
          assert_equal Time.gm(2006,3,10), @node.publish_from # keeps min publication date
        end

        should 'not be allowed to publish and change attributes other then publish_from' do
          assert !@node.update_attributes(:v_status => Zena::Status[:pub], :v_title => "I hack you !")
          assert_not_equal "I hack you !", @node.version.title
        end
      end

    end # A visitor with drive access on a proposition

  end # A visitor with drive access


  # =========== OLD TESTS TO REWRITE =============


  def test_unpublish_all
    login(:tiger)
    visitor.lang = 'fr'
    node = secure!(Node) { nodes(:status)  }
    assert node.unpublish # remove publication
    assert_equal Zena::Status[:rem], node.version.status

    # tiger is a writer, he sees the removed version
    node = secure!(Node) { nodes(:status)  }
    assert_equal Zena::Status[:rem], node.version.status
  end

  def test_can_man_cannot_publish
    login(:ant)
    node = secure!(Note) { Note.create(:name=>'hello', :parent_id=>nodes_id(:cleanWater)) }
    assert !node.new_record?
    assert node.can_drive?, "Can drive"
    assert node.can_drive?, "Can manage"
    assert !node.can_publish?, "Cannot publish"
    assert !node.publish, "Cannot publish"

    node.update_attributes(:inherit=>-1, :v_status => Zena::Status[:red]) # previous 'node.publish' tried to publish node

    assert node.can_drive?, "Can drive"
    assert !node.can_publish?, "Cannot publish"
  end

  def test_unpublish
    login(:lion)
    node = secure!(Node) { nodes(:bananas)  }
    assert node.unpublish # unpublish version
    assert_equal Zena::Status[:rem], node.version.status
  end

  def test_can_unpublish_version
    login(:lion)
    node = secure!(Node) { nodes(:lion) }
    pub_version = node.version
    assert node.can_unpublish?
    assert node.update_attributes(:v_title=>'leopard')
    assert_equal Zena::Status[:red], node.version.status
    assert !node.can_unpublish?
    assert node.can_unpublish?(pub_version)
  end

  def test_backup
    login(:ant)
    visitor.lang = 'en'
    node = secure!(Node) { nodes(:lake) }
    assert_equal Zena::Status[:red], node.version.status
    assert_equal versions_id(:lake_red_en), node.version.id
    assert node.backup, "Backup succeeds"
    #new version
    assert_not_equal versions_id(:lake_red_en), node.version.id
    assert_equal Zena::Status[:red], node.version.status

    #old version
    old_version = versions(:lake_red_en)
    assert_equal Zena::Status[:rep], old_version.status
    node = secure!(Node) { nodes(:lake) }
    assert_equal Zena::Status[:red], node.version.status
  end

  def test_redit
    login(:ant)
    visitor.lang = 'en'
    node = secure!(Node) { nodes(:lake) }
    assert_equal Zena::Status[:red], node.version.status
    assert_equal versions_id(:lake_red_en), node.version.id
    assert node.propose, "Can propose"

    login(:tiger)
    node = secure!(Node) { nodes(:lake) }
    assert node.publish, "Can publish"
    assert_equal Zena::Status[:pub], node.version.status
    assert !node.redit, "Cannot re-edit node"

    login(:ant)
    visitor.lang = 'en'
    node = secure!(Node) { nodes(:lake) }
    assert_equal Zena::Status[:pub], node.version.status
    print 'P'
    #assert node.redit, "Can re-edit node"
    #assert_equal Zena::Status[:red], node.version.status
    #assert_equal versions_id(:lake_red_en), node.version.id
  end

  def test_remove_redaction
    login(:tiger)
    visitor.lang = 'en'
    node = secure!(Node) { nodes(:lake) }
    assert node.can_drive?
    assert_equal Zena::Status[:red], node.version.status
    assert_equal versions_id(:lake_red_en), node.version.id
    assert node.remove, "Can remove"
    assert_equal Zena::Status[:rem], node.version.status
  end

  def test_not_owner_can_remove
    Node.connection.execute "DELETE FROM data_entries"
    login(:lion)
    node = secure!(Node) { nodes(:status) }
    assert_equal users_id(:ant), node.user_id
    assert node.can_apply?(:unpublish)
    assert node.unpublish
    assert node.can_apply?(:destroy_version)
    assert node.destroy_version
    # second version
    node = secure!(Node) { nodes(:status) }
    assert_equal users_id(:ant), node.user_id
    assert node.can_apply?(:unpublish)
    assert node.unpublish
    assert node.can_apply?(:destroy_version)
    assert node.destroy_version
    assert_raise(ActiveRecord::RecordNotFound) { nodes(:status) }
  end

  def test_traductions
    login(:lion) # lang = 'en'
    node = secure!(Node) { nodes(:status) }
    trad = node.traductions
    assert_equal 2, trad.size
    trad_node = trad[0].node
    assert_equal node.object_id, trad_node.target.object_id # make sure object is not reloaded and is secured
    assert_equal 'en', node.version.lang
    assert_equal 'fr', trad[1][:lang]
    node = secure!(Node) { nodes(:wiki) }
    trad = node.traductions
    assert_equal 1, trad.size
  end

  def test_dynamic_attributes
    login(:lion)
    node = secure!(Node) { nodes(:status) }
    node.d_bolo = 'spaghetti bolognese'
    assert node.save, "Can save node"

    # reload
    node = secure!(Node) { nodes(:status) }
    assert_equal 'spaghetti bolognese', node.d_bolo
  end

  def test_root_never_empty
    login(:lion)
    Node.connection.execute "UPDATE nodes SET parent_id = NULL WHERE parent_id = #{nodes_id(:zena)}"
    node = secure!(Node) { nodes(:zena) }
    assert !node.empty?
  end

  def test_empty?
    login(:lion)
    Node.connection.execute "DELETE FROM data_entries"
    Node.connection.execute "UPDATE nodes SET parent_id = NULL WHERE parent_id = #{nodes_id(:people)} AND id <> #{nodes_id(:ant)}"
    node = secure!(Node) { nodes(:people) }
    assert_not_nil node.find(:all, 'nodes')
    assert !node.empty?
    Node.connection.execute "UPDATE nodes SET parent_id = NULL WHERE parent_id = #{nodes_id(:people)}"
    node = secure!(Node) { nodes(:people) }
    assert node.empty?
  end

  def test_destroy
    login(:lion)
    node = secure!(Node) { nodes(:talk) }
    sub  = secure!(Page) { Page.create(:parent_id => nodes_id(:talk), :v_title => 'hello') }
    assert node.update_attributes(:v_title => 'new title')
    assert node.publish

    node = secure!(Node) { nodes(:talk) }
    assert !sub.new_record?
    assert_equal 2, node.versions.size
    assert_equal 1, node.send(:all_children).size

    assert !node.can_destroy_version? # versions are not in 'deleted' status
    Node.connection.execute "UPDATE versions SET status = #{Zena::Status[:rem]} WHERE node_id = #{nodes_id(:talk)}"
    node = secure!(Node) { nodes(:talk) } # reload
    assert node.can_destroy_version? # versions are now in 'deleted' status
    assert node.destroy_version      # 1 version left
    assert_equal 1, node.versions.size

    assert !node.destroy

    assert_equal "cannot be removed (contains subpages or data)", node.errors[:base]

    node = secure!(Node) { nodes(:talk) } # reload
    assert_equal 1, node.versions.size

    assert sub.remove
    assert_equal 1, node.versions.size

    assert sub.destroy_version # destroy all
    node = secure!(Node) { nodes(:talk) } # reload

    assert node.can_destroy_version?
    assert node.destroy_version # destroy all
    assert_raise(ActiveRecord::RecordNotFound) { nodes(:talk) }
  end

  def test_auto_publish_by_status
    # set v_status = 50 ===> publish
    login(:lion)
    node = secure!(Node) { nodes(:status) }
    assert_equal Zena::Status[:pub], node.version.status
    assert_equal 'status title', node.version.title
    assert_equal 1, node.version.number
    assert_equal 2, node.versions.size
    node.update_attributes(:v_title => "Statues are better", 'v_status' => Zena::Status[:pub])
    assert_equal Zena::Status[:pub], node.version.status
    assert_equal 3, node.version.number
    assert_equal 'Statues are better', node.version.title
  end

  def test_auto_publish
    # set site.auto_publish ===> publish
    Site.connection.execute "UPDATE sites set auto_publish = 1, redit_time = 0 WHERE id = #{sites_id(:zena)}"
    login(:lion)
    node = secure!(Node) { nodes(:status) }
    assert_equal Zena::Status[:pub], node.version.status
    assert_equal 'status title', node.version.title
    assert_equal 1, node.version.number
    node.update_attributes(:v_title => "Statues are better")
    assert_equal Zena::Status[:pub], node.version.status
    assert_equal 3, node.version.number
    assert_equal 'Statues are better', node.version.title
  end

  def test_update_auto_publish_set_v_publish_from_to_nil
    Site.connection.execute "UPDATE sites set auto_publish = 1, redit_time = 7200 WHERE id = #{sites_id(:zena)}"
    login(:tiger)
    node = secure!(Node) { Node.create( :parent_id => nodes_id(:zena), :v_title => "This one should auto publish" ) }
    node = secure!(Node) { Node.find(node.id) } # reload
    node.update_attributes(:v_title => "This one should not be gone",  :v_publish_from => "")
    assert_equal Zena::Status[:pub], node.version.status
    assert_equal 'This one should not be gone', node.version.title
    assert_equal Zena::Status[:pub], node.version.status
    assert_not_nil node.publish_from
    assert node.publish_from > Time.now - 10
    assert node.publish_from < Time.now + 10
    assert node.version.publish_from > Time.now - 10
    assert node.version.publish_from < Time.now + 10
  end

  def test_auto_publish_in_redit_time_can_publish
    # set site.auto_publish      ===> publish
    # now < updated + redit_time ===> update current publication
    Site.connection.execute "UPDATE sites set auto_publish = 1, redit_time = 7200 WHERE id = #{sites_id(:zena)}"
    Version.connection.execute "UPDATE versions set updated_at = '#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}' WHERE id = #{versions_id(:tiger_en)}"
    login(:tiger)
    visitor.lang = 'en'
    node = secure!(Node) { nodes(:tiger) }
    assert_equal Zena::Status[:pub], node.version.status
    assert_equal 'Tiger', node.version.title
    assert_equal 1, node.version.number
    assert_equal users_id(:tiger), node.version.user_id
    assert node.version.updated_at < Time.now + 600
    assert node.version.updated_at > Time.now - 600
    assert node.update_attributes(:v_title => "Puma")
    assert_equal Zena::Status[:pub], node.version.status
    assert_equal 1, node.version.number
    assert_equal versions_id(:tiger_en), node.version.id
    assert_equal 'Puma', node.version.title
  end

  def test_publish_after_save_in_redit_time_can_publish
    # set site.auto_publish      ===> publish
    # now < updated + redit_time ===> update current publication
    Site.connection.execute "UPDATE sites set auto_publish = 0, redit_time = 7200 WHERE id = #{sites_id(:zena)}"
    Version.connection.execute "UPDATE versions set updated_at = '#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}' WHERE id = #{versions_id(:tiger_en)}"
    login(:tiger)
    visitor.lang = 'en'
    node = secure!(Node) { nodes(:tiger) }
    assert_equal Zena::Status[:pub], node.version.status
    assert_equal 'Tiger', node.version.title
    assert_equal 1, node.version.number
    assert_equal users_id(:tiger), node.version.user_id
    assert node.version.updated_at < Time.now + 600
    assert node.version.updated_at > Time.now - 600
    assert node.update_attributes(:v_title => "Puma", :v_status => Zena::Status[:pub])
    assert_equal Zena::Status[:pub], node.version.status
    assert_equal 1, node.version.number
    assert_equal versions_id(:tiger_en), node.version.id
    assert_equal 'Puma', node.version.title
  end

  def test_auto_publish_in_redit_time_new_redaction
    # set site.auto_publish      ===> publish
    # now < updated + redit_time ===> refuse
    Site.connection.execute "UPDATE sites set auto_publish = 1, redit_time = 7200 WHERE id = #{sites_id(:zena)}"
    Version.connection.execute "UPDATE versions set updated_at = '#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}' WHERE id = #{versions_id(:status_en)}"
    login(:ant)
    visitor.lang = 'en'
    node = secure!(Node) { nodes(:status) }
    assert_equal Zena::Status[:pub], node.version.status
    assert_equal 'status title', node.version.title
    assert_equal 1, node.version.number
    assert_equal users_id(:ant), node.version.user_id
    assert !node.can_publish?
    assert node.version.updated_at < Time.now + 600
    assert node.version.updated_at > Time.now - 600
    assert node.update_attributes(:v_title => "Statues are better")
    assert_equal Zena::Status[:red], node.version.status
    assert_equal 3, node.version.number
    assert_not_equal versions_id(:status_en), node.version.id
    assert_equal 'Statues are better', node.version.title
  end

  def test_auto_publish_in_redit_time_updates_proposition
    # set site.auto_publish      ===> publish
    # now < updated + redit_time ===> update current proposition
    Site.connection.execute "UPDATE sites set auto_publish = 1, redit_time = 7200 WHERE id = #{sites_id(:zena)}"
    Version.connection.execute "UPDATE versions set status = #{Zena::Status[:prop]}, updated_at = '#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}' WHERE id = #{versions_id(:status_en)}"
    login(:ant)
    visitor.lang = 'en'
    node = secure!(Node) { nodes(:status) }
    assert_equal Zena::Status[:prop], node.version.status
    assert_equal 'status title', node.version.title
    assert_equal 1, node.version.number
    assert_equal users_id(:ant), node.version.user_id
    assert !node.can_publish?
    assert node.version.updated_at < Time.now + 600
    assert node.version.updated_at > Time.now - 600
    assert !node.update_attributes(:v_title => "Statues are better")
    assert_not_equal "Statues are better", node.v_title
  end

  def test_create_auto_publish
    Site.connection.execute "UPDATE sites set auto_publish = 1, redit_time = 7200 WHERE id = #{sites_id(:zena)}"
    login(:tiger)
    node = secure!(Node) { Node.create( :parent_id => nodes_id(:zena), :v_title => "This one should auto publish" ) }
    assert ! node.new_record? , "Not a new record"
    assert ! node.version.new_record? , "Not a new redaction"
    assert_equal Zena::Status[:pub], node.version.status, "published version"
    assert node.publish_from > Time.now - 10
    assert node.publish_from < Time.now + 10
    assert node.version.publish_from > Time.now - 10
    assert node.version.publish_from < Time.now + 10
    assert_equal "This one should auto publish", node.version.title
  end

  def test_create_auto_publish_v_publish_from_to_nil
    Site.connection.execute "UPDATE sites set auto_publish = 1, redit_time = 7200 WHERE id = #{sites_id(:zena)}"
    login(:tiger)
    node = secure!(Node) { Node.create( :parent_id => nodes_id(:zena), :v_title => "This one should auto publish", :v_publish_from => nil ) }
    assert ! node.new_record? , "Not a new record"
    assert ! node.version.new_record? , "Not a new redaction"
    assert_equal Zena::Status[:pub], node.version.status, "published version"
    assert node.publish_from > Time.now - 10
    assert node.publish_from < Time.now + 10
    assert node.version.publish_from > Time.now - 10
    assert node.version.publish_from < Time.now + 10
    assert_equal "This one should auto publish", node.version.title
  end

  def test_set_v_lang_publish
    # publish should replace published item in v_lang
    login(:tiger)
    node = secure!(Node) { nodes(:opening) }
    assert_equal Zena::Status[:pub], node.version.status
    assert_equal 'en', node.version.lang
    pub_v_en = node.version.id
    visitor.lang = 'fr'
    node = secure!(Node) { nodes(:opening) }
    assert_equal Zena::Status[:red], node.version.status
    assert_equal 'fr', node.version.lang
    assert node.update_attributes(:v_lang => 'en', :v_status => Zena::Status[:pub])
    assert_not_equal node.version.id, pub_v_en
    assert_equal Zena::Status[:pub], node.version.status
    assert_equal 'en', node.version.lang
    old_version = Version.find(pub_v_en)
    assert_equal Zena::Status[:rep], old_version.status
  end

  def test_v_status_no_publish_rights
    login(:ant)
    node = secure!(Node) { nodes(:cleanWater) }
    assert !node.can_publish?
    assert node.can_write?
    assert node.update_attributes(:v_title => 'bloated waters', :v_status => Zena::Status[:pub])
    assert_equal Zena::Status[:red], node.version.status
  end

  def test_auto_publish_no_publish_rights
    Site.connection.execute "UPDATE sites set auto_publish = 1, redit_time = 0 WHERE id = #{sites_id(:zena)}"
    login(:ant)
    node = secure!(Node) { nodes(:cleanWater) }
    assert !node.can_publish?
    assert node.update_attributes(:v_title => 'bloated waters')
    assert_equal Zena::Status[:red], node.version.status
  end

  def test_status
    login(:tiger)
    node = secure!(Node) { Node.new(defaults) }

    assert node.save, "Node saved"
    assert_equal Zena::Status[:red], node.version.status
    assert node.propose, "Can propose node"
    assert_equal Zena::Status[:prop], node.version.status
    assert node.publish, "Can publish node"
    assert_equal Zena::Status[:pub], node.version.status
    assert node.publish_from <= Time.now, "node publish_from is smaller the Time.now"
    login(:ant)
    assert_nothing_raised { node = secure!(Node) { Node.find(node.id) } }
    assert node.update_attributes(:v_summary=>'hello my friends'), "Can create a new edition"
    assert_equal Zena::Status[:red], node.version.status
    assert node.propose, "Can propose edition"
    assert_equal Zena::Status[:prop], node.version.status
    # WE CAN USE THIS TO TEST vhash (version hash cache) when it's implemented
  end

  def test_publish_with_v_status
    login(:tiger)
    node = secure!(Node) { nodes(:cleanWater)  }
    assert node.update_attributes(:v_title => "dirty")
    node = secure!(Node) { nodes(:cleanWater)  }
    assert_equal Zena::Status[:red], node.version.status
    assert node.update_attributes(:v_status => Zena::Status[:pub])
    node = secure!(Node) { nodes(:cleanWater)  }
    assert_equal Zena::Status[:pub], node.version.status
  end

  def test_transition_allowed
    login(:tiger) # can do everything
    node = secure!(Node) { nodes(:status) }
    assert node.can_apply?(:edit)
  end
end