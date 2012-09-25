module Zafu
  # A Markup object is used to hold information on the tag used (<li>), it's parameters (.. class='xxx') and
  # indentation.
  class Markup
    EMPTY_TAGS   = %w{meta input link img}
    STEAL_PARAMS = {
      'link'   => [:href, :charset, :rel, :type, :media, :rev, :target],
      'a'      => [:title, :onclick, :target],
      'script' => [:type, :charset, :defer],
      :other   => [:class, :id, :style],
    }

    # Tag used ("li" for example). The tag can be nil (no tag).
    attr_accessor :tag
    # Tag parameters (.. class='xxx' id='yyy')
    attr_accessor :params
    # Dynamic tag parameters that should not be escaped. For example: (.. class='<%= @node.klass %>')
    attr_accessor :dyn_params
    # Ensure wrap is not called more then once unless this attribute has been reset in between
    attr_accessor :done
    # Space to insert before tag
    attr_accessor :space_before
    # Space to insert after tag
    attr_accessor :space_after
    # Keys to remove from zafu and use for the tag itself
    attr_writer   :steal_keys

    class << self

      # Parse parameters into a hash. This parsing supports multiple values for one key by creating additional keys:
      # <tag do='hello' or='goodbye' or='gotohell'> creates the hash {:do=>'hello', :or=>'goodbye', :or1=>'gotohell'}
      def parse_params(text)
        return Zafu::OrderedHash.new unless text
        return text if text.kind_of?(Hash)
        params = Zafu::OrderedHash.new
        rest = text.strip
        while (rest != '')
          if rest =~ /(.+?)=/
            key = $1.strip.to_sym
            rest = rest[$&.length..-1].strip
            if rest =~ /('|")(|[^\1]*?[^\\])\1/
              rest = rest[$&.length..-1].strip
              key_counter = 1
              while params[key]
                key = "#{key}#{key_counter}".to_sym
                key_counter += 1
              end

              if $1 == "'"
                params[key] = $2.gsub("\\'", "'")
              else
                params[key] = $2.gsub('\\"', '"')
              end
            else
              # error, bad format, return found params.
              break
            end
          else
            # error, bad format
            break
          end
        end
        params
      end
    end

    def initialize(tag, params = nil)
      @done       = false
      @tag        = tag
      if params
        self.params = params
      else
        @params = Zafu::OrderedHash.new
      end
      @dyn_params = Zafu::OrderedHash.new
    end

    # Set params either using a string (like "alt='time passes' class='zen'")
    def params=(p)
      if p.kind_of?(Hash)
        @params = p
      else
        @params = Markup.parse_params(p)
      end
    end

    # Another way to set dynamic params (the argument must be a hash).
    def dyn_params=(h)
      set_dyn_params(h)
    end

    # Steal html parameters from an existing hash (the stolen parameters are removed
    # from the argument)
    def steal_html_params_from(p)
      p.delete_if do |k,v|
        if steal_keys.include?(k) || k =~ /^data-/
          @params[k] = v
          true
        else
          false
        end
      end
    end

    # Compile dynamic parameters as ERB. A parameter is considered dynamic if it
    # contains the string eval "#{...}"
    def compile_params(helper)
      @params.each do |key, value|
        if value =~ /^(.*)\#\{(.*)\}(.*)$/
          @params.delete(key)
          if $1 == '' && $3 == ''
            code = RubyLess.translate(helper, $2)
            if code.literal
              append_dyn_param(key, helper.form_quote(code.literal.to_s))
            else
              append_dyn_param(key, "<%= #{code} %>")
            end
          else
            code = RubyLess.translate_string(helper, value)
            if code.literal
              append_dyn_param(key, helper.form_quote(code.literal.to_s))
            else
              append_dyn_param(key, "<%= #{code} %>")
            end
          end
        end
      end
    end

    # Set dynamic html parameters.
    def set_dyn_params(hash)
      hash.each do |k,v|
        set_dyn_param(k, v)
      end
    end

    # Set dynamic html parameters.
    def set_dyn_param(key, value)
      @params.delete(key)
      @dyn_params[key] = value
    end

    # Set static html parameters.
    def set_params(hash)
      hash.each do |k,v|
        set_param(k, v)
      end
    end

    # Set static html parameters.
    def set_param(key, value)
      @dyn_params.delete(key)
      @params[key] = value
    end

    def prepend_param(key, value)
      if prev_value = @dyn_params[key]
        @dyn_params[key] = "#{value} #{prev_value}"
      elsif prev_value = @params[key]
        @params[key] = "#{value} #{prev_value}"
      else
        @params[key] = value
      end
    end

    def append_param(key, value)
      if prev_value = @dyn_params[key]
        @dyn_params[key] = "#{prev_value} #{value}"
      elsif prev_value = @params[key]
        @params[key] = "#{prev_value} #{value}"
      else
        @params[key] = value
      end
    end

    def prepend_dyn_param(key, value, conditional = false)
      spacer = conditional ? '' : ' '
      if prev_value = @params.delete(key)
        @dyn_params[key] = "#{value}#{spacer}#{prev_value}"
      elsif prev_value = @dyn_params[key]
        @dyn_params[key] = "#{value}#{spacer}#{prev_value}"
      else
        @dyn_params[key] = value
      end
    end

    def append_attribute(text_to_append)
      (@append ||= '') << text_to_append
    end

    def append_dyn_param(key, value, conditional = false)
      spacer = conditional ? '' : ' '
      if prev_value = @params.delete(key)
        @dyn_params[key] = "#{prev_value}#{spacer}#{value}"
      elsif prev_value = @dyn_params[key]
        @dyn_params[key] = "#{prev_value}#{spacer}#{value}"
      else
        @dyn_params[key] = value
      end
    end

    # Define the DOM id from a node context
    def set_id(erb_id)
      params[:id] = nil
      dyn_params[:id] = erb_id
    end

    # Return true if the given key exists in params or dyn_params.
    def has_param?(key)
      params[key] || dyn_params[key]
    end

    # Duplicate markup and make sure params and dyn_params are duplicated as well.
    def dup
      markup = super
      markup.instance_variable_set(:@params, @params.dup)
      markup.instance_variable_set(:@dyn_params, @dyn_params.dup)
      markup.instance_variable_set(:@pre_wrap, @pre_wrap.dup) if @pre_wrap
      markup
    end

    # Store some text to insert at the beggining of the tag content on wrap. Inserted
    # elements are indexed in a hash but only values are shown.
    def pre_wrap
      @pre_wrap ||= {}
    end

    # Wrap the given text with our tag. If 'append' is not empty, append the text
    # after the tag parameters: <li class='foo'[APPEND HERE]>text</li>.
    def wrap(text)
      return text if @done

      text = "#{@pre_wrap.values}#{text}" if @pre_wrap

      if dyn_params[:id]
        @tag ||= 'div'
      end

      if @tag
        if text.blank? && EMPTY_TAGS.include?(@tag)
          res = "#{@pre_wrap}<#{@tag}#{params_to_html}#{@append}/>"
        else
          res = "<#{@tag}#{params_to_html}#{@append}>#{text}</#{@tag}>"
        end
      else
        res = text
      end
      @done = true

      (@space_before || '') + res + (@space_after || '')
    end

    def to_s
      wrap(nil)
    end

    def steal_keys
      @steal_keys || (STEAL_PARAMS[@tag] || []) + STEAL_PARAMS[:other]
    end

    private
    if RAILS_ENV == 'test'
      def params_to_html
        para = []
        keys = @dyn_params.keys

        @params.each do |k, v|
          next if keys.include?(k)

          if !v.to_s.include?("'")
            para << " #{k}='#{v}'"
          else
            para << " #{k}=\"#{v.to_s.gsub('"','\"')}\"" # TODO: do this work in all cases ?
          end
        end

        keys.each do |k|
          para << " #{k}='#{@dyn_params[k]}'"
        end

        para
      end
    else
      def params_to_html
        para = []
        keys = @dyn_params.keys

        @params.each do |k,v|
          next if keys.include?(k)

          if !v.to_s.include?("'")
            para << " #{k}='#{v}'"
          else
            para << " #{k}=\"#{v.to_s.gsub('"','\"')}\"" # TODO: do this work in all cases ?
          end
        end

        @dyn_params.each do |k,v|
          para << " #{k}='#{v}'"
        end

        para
      end
    end

  end
end