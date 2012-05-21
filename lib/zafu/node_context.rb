module Zafu
  class NodeContext
    # The name of the variable halding the current object or list ("@node", "var1")
    attr_reader :name

    # The previous NodeContext
    attr_reader :up

    # The type of object contained in the current context (Node, Page, Image)
    attr_reader :klass

    # The current DOM prefix to use when building DOM ids. This is set by the parser when
    # it has a name or dom id defined ('main', 'related', 'list', etc).
    attr_writer :dom_prefix

    # This is used to force a given dom_id (in saved templates for example).
    attr_accessor :saved_dom_id

    # Any kind of information that the compiler might need to use (QueryBuilder query used
    # to fetch the node for example).
    attr_reader :opts

    def initialize(name, klass, up = nil, opts = {})
      @name, @klass, @up, @opts = name, klass, up, opts
    end

    def move_to(name, klass, opts={})
      self.class.new(name, klass, self, opts)
    end

    # Since the idiom to write the node context name is the main purpose of this class, it
    # deserves this shortcut.
    def to_s
      name
    end

    def single_class
      @single_class ||= Array(klass).flatten.first
    end

    # Return true if the NodeContext represents an element of the given type. We use 'will_be' because
    # it is equivalent to 'is_a', but for future objects (during rendering).
    def will_be?(type)
      single_class <= type
    end

    # Return a new node context that corresponds to the current object when rendered alone (in an ajax response or
    # from a direct 'show' in a controller). The returned node context has no parent (up is nil).
    # The convention is to use the class of the current object to build this name.
    # You can also use an 'after_class' parameter to move up in the current object's class hierarchy to get
    # ivar name (see #master_class).
    def as_main(after_class = nil)
      klass = after_class ? master_class(after_class) : single_class
      res = self.class.new("@#{klass.to_s.underscore}", single_class, nil)
      res.propagate_dom_scope! if @dom_scope
      res.dom_prefix = self.dom_prefix
      res
    end

    # Find the class just afer 'after_class' in the class hierarchy.
    # For example if we have Dog < Mamal < Animal < Creature,
    # master_class(Creature) would return Animal
    def master_class(after_class)
      klass = single_class
      begin
        up = klass.superclass
        return klass if up == after_class
      end while klass = up
      return self.klass
    end

    # Generate a unique DOM id for this element based on dom_scopes defined in parent contexts.
    # :code option returns ruby
    # :erb  option returns either string content or "<%= ... %>"
    #       default returns something to insert in interpolated string such as '#{xxx}'
    def dom_id(opts = {})
      dom_prefix = opts[:dom_prefix] || self.dom_prefix
      options = {:list => true, :erb => true}.merge(opts)

      if options[:erb] || options[:code]
        dom = dom_id(options.merge(:erb => false, :code => false))

        if dom =~ /^#\{([^\{]+)\}$/
          code = $1
        elsif dom =~ /#\{/
          code = "%Q{#{dom}}"
        else
          str  = dom
          code = dom.inspect
        end

        if options[:code]
          code
        else
          str || "<%= #{code} %>"
        end
      else
        @saved_dom_id || if options[:list]
          scopes = dom_scopes
          scopes = [dom_prefix] if scopes.empty?
          scopes + [make_scope_id]
        else
          scopes = dom_scopes
          scopes + ((@up || scopes.empty?) ? [dom_prefix] : [])
        end.compact.uniq.join('_')
      end
    end

    # This holds the current context's unique name if it has it's own or one from the hierarchy. If
    # none is found, it builds one.
    def dom_prefix
      @dom_prefix || (@up ? @up.dom_prefix : nil)
    end

    # Return dom_prefix without looking up.
    def raw_dom_prefix
      @dom_prefix
    end

    # Mark the current context as being a looping element (each) whose DOM id needs to be propagated to sub-nodes
    # in order to ensure uniqueness of the dom_id (loops in loops problem).
    def propagate_dom_scope!
      @dom_scope = true
    end

    # Returns the first occurence of the klass up in the hierachy
    # This does not resolve [Node] as [Node].first.
    def get(klass)
      if list_context?
        return @up ? @up.get(klass) : nil
      end
      if self.klass <= klass
        self
        # return self unless list_context?
        #
        # res_class = self.klass
        # method = self.name
        # while res_class.kind_of?(Array)
        #   method = "#{method}.first"
        #   res_class = res_class.first
        # end
        # move_to(method, res_class)
      elsif @up
        @up.get(klass)
      else
        nil
      end
    end

    def up(klass = nil)
      klass ? @up.get(klass) : @up
    end

    # Return true if the current klass is an Array.
    def list_context?
      klass.kind_of?(Array)
    end

    # Return the name of the current class with underscores like 'sub_page'.
    def underscore
      class_name.to_s.underscore
    end

    # Return the 'real' class name or the superclass name if the current class is an anonymous class.
    def class_name
      klass = single_class
      while klass.name == ''
        klass = klass.superclass
      end
      if list_context?
        "[#{klass}]"
      else
        klass.name
      end
    end

    # Return the name to use for input fields
    def form_name
      @form_name ||= master_class(ActiveRecord::Base).name.underscore
    end

    protected
      # List of scopes defined in ancestry (used to generate dom_id).
      def dom_scopes
        return [@saved_dom_id] if @dom_scope && @saved_dom_id
        if @up
          scopes = @up.dom_scopes
          if @dom_scope
            (scopes.empty? ? [dom_prefix] : scopes) + [make_scope_id]
          else
            scopes
          end
        else
          @dom_scope ? [dom_prefix, make_scope_id] : []
        end
      end

    private
      def make_scope_id
        "\#{#{@name}.zip}"
      end
  end
end