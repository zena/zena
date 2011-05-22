require 'helper'
require 'bricks/pdf/engine/prince'

class TestPrince < Test::Unit::TestCase
  context 'With a Prince based Pdf engine' do
    subject do
      Module.new do
        extend Bricks::Pdf
        extend Bricks::Pdf::Engine::Prince
      end
    end

    should_behave_as_pdf_engine
  end # With a Prince based Pdf engine
end