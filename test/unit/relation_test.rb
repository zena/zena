require 'test_helper'

# Test Relation. RelationProxy is tested in its own file.
class RelationTest < Zena::Unit::TestCase

  context 'A visitor that is not an admin' do
    setup do
      login(:ant)
    end

    context 'on relation create' do
      subject do
        Relation.create(:source_role => 'wife', :target_role => 'husband', :source_kpath => 'NRC', :target_kpath => 'NRC', :source_icon => "<img src='/img/user_pink.png'/>", :target_icon => "<img src='/img/user_blue.png'/>")
      end

      should 'fail' do
        assert_difference('Relation.count', 0) do
          assert subject.new_record?
          assert_equal 'You do not have the rights to do this.', subject.errors[:base]
        end
      end
    end # on relation create

    context 'on relation update' do
      subject do
        Relation.create(:source_role => 'wife', :target_role => 'husband', :source_kpath => 'NRC', :target_kpath => 'NRC', :source_icon => "<img src='/img/user_pink.png'/>", :target_icon => "<img src='/img/user_blue.png'/>")
        relations(:node_has_tags)
      end

      should 'fail' do
        assert !subject.update_attributes(:target_kpath => 'NP')
        assert_equal 'You do not have the rights to do this.', subject.errors[:base]
      end
    end # on relation update
  end # A visitor that is not an admin

  context 'A visitor that is an admin' do
    setup do
      login(:lion)
    end

    context 'on relation create' do
      subject do
        Relation.create(
          :source_role  => 'wife',
          :target_role  => 'husband',
          :source_kpath => 'NRC',
          :target_kpath => 'NRC',
          :source_icon  => "<img src='/img/user_pink.png'/>",
          :target_icon  => "<img src='/img/user_blue.png'/>"
        )
      end

      should 'succeed' do
        assert_difference('Relation.count', 1) do
          assert !subject.new_record?
        end
      end

      should 'set site_id' do
        assert_equal sites_id(:zena), subject.site_id
      end

      context 'with a relation group' do
        subject do
          Relation.create(
            :source_role  => 'wife',
            :target_role  => 'husband',
            :source_kpath => 'NRC',
            :target_kpath => 'NRC',
            :rel_group    => 'marital'
          )
        end

        should 'succeed' do
          assert !subject.new_record?
        end

        should 'store rel_group info in relation' do
          assert_equal 'marital', Relation.find(subject).rel_group
        end
      end # with a group

      context 'with blank source_role' do
        subject do
          Relation.create(
            :source_role  => '',
            :target_role  => 'husband',
            :source_kpath => 'NP',
            :target_kpath => 'NRC'
          )
        end

        should 'succeed' do
          assert !subject.new_record?
        end

        should 'use source class as source name' do
          assert_equal 'pages', subject.source_role
        end
      end # with blank source_role

      context 'with plural source_role' do
        subject do
          Relation.create(
            :source_role  => 'wives',
            :source_unique=> false,
            :target_role  => 'husband',
            :source_kpath => 'NP',
            :target_kpath => 'NRC'
          )
        end

        should 'succeed' do
          assert !subject.new_record?
        end

        should 'singularize source role' do
          assert_equal 'wife', subject[:source_role]
        end

        should 'show source role as plural' do
          assert_equal 'wives', subject.source_role
        end
      end # with plural source_role

      context 'with plural target_role' do
        subject do
          Relation.create(
            :source_role  => 'wife',
            :target_role  => 'husbands',
            :target_unique => false,
            :source_kpath => 'NP',
            :target_kpath => 'NRC'
          )
        end

        should 'succeed' do
          assert !subject.new_record?
        end

        should 'singularize target role' do
          assert_equal 'husband', subject[:target_role]
        end

        should 'show target role as plural' do
          assert_equal 'husbands', subject.target_role
        end
      end # with plural source_role

      context 'with blank target_role' do
        subject do
          Relation.create(
            :source_role   => 'wife',
            :target_role   => '',
            :source_kpath  => 'NP',
            :target_kpath  => 'NRC',
            :target_unique => true
          )
        end

        should 'succeed' do
          assert !subject.new_record?
        end

        should 'use target class as target name' do
          assert_equal 'contact', subject.target_role
        end
      end # with blank source_role
    end # on relation create

    context 'on relation update' do
      subject do
        Relation.create(:source_role => 'wife', :target_role => 'husband', :source_kpath => 'NRC', :target_kpath => 'NRC', :source_icon => "<img src='/img/user_pink.png'/>", :target_icon => "<img src='/img/user_blue.png'/>")
        relations(:node_has_tags)
      end

      should 'succeed' do
        assert subject.update_attributes(:target_kpath => 'NP')
      end
    end # on relation update
  end # A visitor that is not an admin


  def test_cannot_set_site_id
    login(:lion) # admin
    relation = Relation.create(:source_role => 'wife', :target_role => 'husband', :source_kpath => 'NRC', :target_kpath => 'NRC', :source_icon => "<img src='/img/user_pink.png'/>", :target_icon => "<img src='/img/user_blue.png'/>", :site_id => sites_id(:ocean))
    assert !relation.new_record?
    assert_equal sites_id(:zena), relation[:site_id]
  end

  def test_set_site_id
    login(:lion) # admin
    relation = relations(:node_has_tags)
    original_site_id = relation.site_id
    relation.update_attributes(:site_id => 1234)
    assert_equal original_site_id, relation.site_id
  end

end
