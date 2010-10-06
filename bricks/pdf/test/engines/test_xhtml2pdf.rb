require 'helper'
require 'bricks/pdf/engine/xhtml2pdf'

class TestXhtml2pdf < Test::Unit::TestCase
  context 'With a Prince based PDF engine' do
    subject do
      Module.new do
        extend Bricks::PDF
        extend Bricks::PDF::Engine::Xhtml2pdf
      end
    end

    should_behave_as_pdf_engine
  end # With a Xhtml2pdf based PDF engine
end