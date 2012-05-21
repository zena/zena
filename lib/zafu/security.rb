module Zafu
  module Security
    SECURE_REGEXP = %r{<%|%>|<\Z}
    SAFE_CODE     = {'<%' => '&lt;%', '%>' => '%&gt;', '<' => '&lt;'}
    # Make sure translations and other literal values cannot be used to build erb.
    def erb_escape(text)
      # Do not only replace '<%' ! or <r:t>min</r:t>% ==> <% ...
      text.gsub(SECURE_REGEXP) {|code| SAFE_CODE[code]}
    end

    def form_quote(text)
      erb_escape(text).gsub("'", "&apos;")
    end
  end # Security
end # Zafu