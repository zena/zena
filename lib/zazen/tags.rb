module Zazen
  module Tags
    # This is not exactly how compile/render is meant to work with Parser, but there is no real need for a two step
    # rendering, so we compile here (enter(:void)) instead of doing this whith 'start'. This also lets us have the
    # context during compilation which makes it easier to manage the callbacks to the helper.
    def r_void
      @context = {:images => true, :pretty_code=>true, :output => 'html'}.merge(@context)
      @translate_ids = @context[:translate_ids]
      @text = @text.gsub("\r\n","\n") # this also creates our own 'working' copy of the text
      @blocks = "" # same reason as why we rewrite 'store'

      extract_code(@text)

      # set whether the first paragraphe is spaced preserved.
      @in_space_pre = (@text[0..0] == ' ')

      enter(:void) # <== parse here

      unless @translate_ids
        store '</pre>' if @in_space_pre

        case @context[:output]
        when 'html'
          # TODO: we should write our own parser for textile with rendering formats...
          @text = RedCloth.new(@blocks).to_html
        when 'latex'
          # replace RedCloth markup by latex equivalent
          @text = RedCloth.new(@blocks).to_latex
        end

        # Replace placeholders by their real values
        @helper.replace_placeholders(@text) if @helper.respond_to?('replace_placeholders')
        @blocks = ""
        enter(:wiki)
      end
      render_code(@blocks)
      @blocks
    end
  end
end