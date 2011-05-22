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


  def self.should_behave_as_pdf_engine

    context 'Rendering from file' do
      setup do
        @dir = File.dirname(__FILE__)
      end

      should 'create a pdf file if the destination is a file' do
        assert_exist contact_pdf do
          subject.render(:input => contact_html, :output => contact_pdf)
        end
      end

      should 'fill STDOUT if no destination is specified' do
        assert_match %r{^%Pdf}, subject.render(:input => contact_html)
      end
    end


    context 'Rendering from STDIN' do
      should 'create pdf file if destination is a file' do
        assert_exist contact_pdf do
          subject.render(:data => '<html>Hello World</html>', :output => contact_pdf)
        end
      end

      should 'fill STDOUT if no destination is specified' do
        assert_match %r{^%Pdf}, subject.render(:data => '<html>Hello World</html>')
      end
    end

    context 'Rendering with http auth' do
      setup do
        @login    = 'ABCDLOGINABCD'
        @password = '7787PASSWORD8'
      end

      should 'include http user in command' do
        assert_match %r{#{@login}}, subject.command(:http_user => @login, :http_password => @password)
      end

      should 'include http password in command' do
        assert_match %r{#{@password}}, subject.command(:http_user => @login, :http_password => @password)
      end
    end

    context 'Rendering with baseurl' do
      setup do
        @baseurl  = 'http://localhost:7999'
      end

      should 'include baseurl in command' do
        assert_match %r{#{@baseurl}}, subject.command(:baseurl => @baseurl)
      end
    end
  end # should_behave_as_pdf_engine
end # Test::Unit::TestCase