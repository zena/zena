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
        
        should 'load all roles on update_attributes' do
          assert_nothing_raised do
            assert subject.update_attributes('assigned' => 'flat Eric')
          end
        end
      end # from a class with roles
    end # on a node
  end # A visitor with write access
end
