module Test #:nodoc:
  module Unit #:nodoc:
    module Assertions
      # You can use these assertions to test your RJS responses.
      
      # Asserts that a tag exists in the HTML being set by a JavaScript response.
      # If an id is specified, asserts that the tag exists in that block.  Otherwise,
      # the assert will check all Element.update and new Insertation.* statements for
      # the tag specified.
      #
      # Although it is possible for multiple tags to match the conditions in multiple
      # blocks, only one needs to exist for the assert to pass.
      #
      # assert_rjs_tag :rjs => {:block => 'my_div_id'}, :tag => 'span'
      #
      # Note: At this time, tag types must explicitly use :tag =>.
      def assert_rjs_tag(*opts)
        clean_backtrace do
          options = opts[0]
          
          applicable_html = applicable_html_slices(options)
          if find_tags_in_html(applicable_html, options).size < 1
            assert false, "Could not find tag in RJS response!  RJS response: #{@response.body}"
          end
        end   # clean_backtrace
      end   # assert_rjs_tag

      # Similar to assert_rjs_tag, but asserts that a tag does NOT exist.
      def assert_rjs_no_tag(*opts)
        clean_backtrace do
          options = opts[0]
          
          applicable_html = applicable_html_slices(options)

          if find_tags_in_html(applicable_html, options).size > 0
            assert false, "Found a tag that matched the criteria!  None was expected."
          end
        end   # clean_backtrace
      end   # assert_rjs_no_tag
      
      
      def assert_rjs_visual_effect(id, effect, options = {})
        effect = effect.to_s.underscore if effect.kind_of?(Symbol)

        response_lines.each do |line|
          found = case effect
                  when "show"
                    line["Element.show(\"#{id}\");"]
                  when "hide"
                    line["Element.hide(\"#{id}\");"]
                  end
                  
          return unless found.nil?
        end
        
        assert false, "Visual Effect not found!  Expected a #{effect} effect, but none present in: #{@response.body}"
      end   # assert_rjs_visual_effect
      
      private
      
      # Returns an array of HTML chunks that match the RJS criteria.
      def applicable_html_slices(options)
        applicable_html = []
        
        response_lines.each do |cmd|
          if (cmd.include?("Element.") || cmd.include?("new Insertion."))
            if options[:rjs][:block] && cmd.include?("(\"#{options[:rjs][:block]}\", \"")
              start_index = cmd.index("\"") + options[:rjs][:block].size + 5
              applicable_html << cmd[start_index..(cmd.size-4)].gsub('\"', '"').gsub('\n', "\n").gsub('\t', "\t")
            elsif (options[:rjs].nil? || options[:rjs][:block].nil?)
              start_index = cmd.index("\", \"") + 4
              applicable_html << cmd[start_index..(cmd.size-4)].gsub('\"', '"').gsub('\n', "\n").gsub('\t', "\t")
            end
          end
        end
        
        applicable_html
      end   # applicable_html_slices

      def find_tags_in_html(html_slices, options)
        options.delete(:rjs)    # HTML::Document won't like :rjs
        
        return_val = []
        
        html_slices.each do |html|
          document ||= HTML::Document.new(html)
          return_val << document.find(options) if document.find(options)
        end

        return_val
      end   # find_tags_in_html

      def response_lines
        @response.body.split("\n")
      end

    end
  end
end