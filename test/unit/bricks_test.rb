require 'test_helper'

class BricksTest < Zena::Unit::TestCase

  context 'The Bricks module' do
    subject do
      Bricks
    end

    should 'run command with run' do
      ok, msg, err = subject.run(nil, 'date', '+%Y')
      assert(ok)
      assert_match(/^\d+\n$/, msg)
    end

    should 'get return result with run' do
      ok, msg, err = subject.run(nil, 'false')
      assert(!ok)

      ok, msg, err = subject.run(nil, 'true')
      assert(ok)
    end
  end # The Bricks module
end
