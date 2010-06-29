class Test::Unit::TestCase

  def setup
   @dir = File.dirname(__FILE__)
  end

  def contact_html
   File.join(@dir, '..', 'fixtures', 'contact.html')
  end

  def contact_pdf
    File.join(@dir, '..', 'fixtures', 'contact.pdf')
  end

  def self.should_act_as_an_engine

    engine = Data2pdf.engine
    engine_module = Data2pdf.const_get engine

    context "Module #{engine}" do

      subject{ engine_module }

      should 'define interface methodes' do
        assert subject.method_defined? :binary
        assert subject.method_defined? :stylesheet
        assert subject.method_defined? :source
        assert subject.method_defined? :destination
      end

    end

  end # should_implement_data2pdf_interface


  def self.should_render_pdf_from_file

    context 'Rendering from file' do

      setup do
        @dir = File.dirname(__FILE__)
      end

      should 'create a pdf file if the destination is a file' do
        assert_exist contact_pdf do
          Data2pdf.render contact_html, contact_pdf
        end
      end

      should 'fill STDOUT if no destination is specified' do
        assert_match(/^%PDF/, Data2pdf.render(contact_html))
      end

    end

  end # should_render_pdf_from_file


  def self.should_render_pdf_from_STDIN

    context 'Rendering from STDIN' do

      should 'create pdf file if destination is a file' do
        assert_exist File.join(@dir, '..', 'fixtures', 'from-strings.pdf') do
          Data2pdf.render '<html>Hello World</html>', File.join(@dir, '..', 'fixtures', 'from-strings.pdf')
        end
      end

      should 'fill STDOUT if no destination is specified' do
        assert_match(/^%PDF/, Data2pdf.render('<html>Hello World</html>'))
      end

    end

  end # should_render_pdf_from_STDIN

  def self.should_render_with_css_option

    context 'Rendering with :css option' do

      should 'create pdf if one file is specified' do
        assert_exist contact_pdf do
          Data2pdf.render contact_html, contact_pdf, :css=>File.join(@dir, '..', 'fixtures', 'application.css')
        end
      end

    end

  end # render_with_css_option

end # Test::Unit::TestCase