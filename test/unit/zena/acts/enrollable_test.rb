require 'test_helper'

class EnrollableTest < Zena::Unit::TestCase

  context 'A visitor with write access' do
    setup do
      login(:tiger)
    end

    context 'on a node' do
      context 'from a class with roles' do
        subject do
          secure(Node) { nodes(:letter) }
        end
        
        should 'raise an error before role is loaded' do
          assert_raise(NoMethodError) do
            subject.assigned = 'flat Eric'
          end
        end
        
        should 'load all roles on set attributes' do
          assert_nothing_raised do
            subject.attributes = {'assigned' => 'flat Eric'}
          end
        end
        
        should 'load all roles on set properties' do
          subject.properties = {'assigned' => 'flat Eric'}
          assert subject.save
          assert_equal 'flat Eric', subject.assigned
        end
        
        should 'load all roles on update_attributes' do
          assert_nothing_raised do
            assert subject.update_attributes('assigned' => 'flat Eric')
          end
        end
        
        should 'accept properties in update_attributes' do
          assert_nothing_raised do
            assert subject.update_attributes('properties' => {'assigned' => 'flat Eric'})
            assert_equal 'flat Eric', subject.assigned
          end
        end
        
        should 'not allow arbitrary attributes' do
          assert_raise(ActiveRecord::UnknownAttributeError) do
            assert subject.update_attributes('assigned' => 'flat Eric', 'bad' => 'property')
          end
        end
        
        should 'not allow property bypassing' do
          assert !subject.update_attributes('properties' => {'bad' => 'property'})
          assert_equal 'property not declared', subject.errors[:bad]
        end
        
        context 'with properties assigned through role' do
          subject do
            secure(Node) { nodes(:status) }
          end
          
          should 'read attributes without loading roles' do
            assert_equal 'gaspard', subject.prop['assigned']
            assert !subject.respond_to?(:assigned)
          end
        end # with properties assigned through role
      end # from a class with roles
    end # on a node
  end # A visitor with write access
end
