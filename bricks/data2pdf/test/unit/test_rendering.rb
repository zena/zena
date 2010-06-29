require 'helper'

class TestRendering < Test::Unit::TestCase

  context "Rendering" do

    should 'implement #command that calls binary and methods' do
      Data2pdf.expects(:binary).returns('engine')
      (assert_equal 'engine  foo.html foo.pdf', (Data2pdf.send :command, 'foo.html', 'foo.pdf'))
    end

    should 'implement #render that returns pdf file name if destination is file' do
      Data2pdf.stubs(:source).returns(['some-file.html', File])
      Data2pdf.stubs(:destination).returns(['some-file.pdf', File])
      Data2pdf.stubs(:stylesheet).returns(nil)
      Data2pdf.stubs(:binary).returns('engine')
      Data2pdf.stubs(:quiet_option).returns('-q')
      io = IO.popen('ls','w+')
      IO.stubs(:popen).returns(io)
      (assert_equal 'some-file.pdf', (Data2pdf.render 'some-file.html', 'some-file.pdf'))
    end

  end

  context 'Engine' do

    should 'be specified with #engine=' do
      Data2pdf.engine = 'Prince'
      assert_equal 'Prince', Data2pdf.engine
    end

  end


end


