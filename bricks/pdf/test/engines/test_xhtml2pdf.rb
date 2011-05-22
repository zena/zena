require 'helper'
require 'bricks/pdf/engine/xhtml2pdf'

class TestXhtml2pdf < Test::Unit::TestCase
  context 'With a Prince based Pdf engine' do
    subject do
      Module.new do
        extend Bricks::Pdf
        extend Bricks::Pdf::Engine::Xhtml2pdf
      end
    end

    should_behave_as_pdf_engine
  end # With a Xhtml2pdf based Pdf engine
end