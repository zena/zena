require 'helper'
Data2pdf.engine = 'Prince'

class TestPrince < Test::Unit::TestCase

  should_act_as_an_engine

  should_render_pdf_from_file

  should_render_pdf_from_STDIN

  should_render_with_css_option

end