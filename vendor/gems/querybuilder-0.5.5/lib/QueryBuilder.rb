$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'yaml'

=begin rdoc
QueryBuilder is a tool to secure and simplify the creation of SQL queries from untrusted users.

Syntax of a query is "RELATION [where ...|] [in ...|from SUB_QUERY|]".
=end
class QueryBuilder
  attr_reader :tables, :where, :errors, :join_tables, :distinct, :final_parser, :page_size
  VERSION = '0.5.5'
  
  @@main_table = {}
  @@main_class = {}
  @@custom_queries = {}
  
  class << self
    # This is the table name of the main class.
    def set_main_table(table_name)
      @@main_table[self] = table_name.to_s
    end
    
    # This is the class of the returned elements if there is no class change in the query. This
    # should correspond to the class used to build call "Foo.find_by_sql(...)" (Foo).
    def set_main_class(main_class)
      @@main_class[self] = main_class.to_s
    end
    
    # Load prepared SQL definitions from a set of directories. If the file does not contain "host" or "hosts" keys,
    # the filename is used as host.
    #
    # ==== Parameters
    # query<String>:: Path to list of custom queries yaml files.
    #
    # ==== Examples
    #   DummyQuery.load_custom_queries("/path/to/some/*/directory")
    #
    # The format of a custom query definition is:
    #
    #   hosts:
    #     - test.host
    #   DummyQuery:      # QueryBuilder class
    #     abc:           # query's relation name
    #       select:      # selected fields
    #         - 'a'
    #         - '34 AS number'
    #         - 'c'
    #       tables:      # tables used
    #         - 'test'
    #       join_tables: # joins
    #         test:
    #           - LEFT JOIN other ON other.test_id = test.id
    #       where:    # filters
    #         - '1'
    #         - '2'
    #         - '3'
    #       order:  'a DESC' # order clause
    #
    # Once loaded, this 'custom query' can be used in a query like:
    #   "images from abc where a > 54"
    def load_custom_queries(directories)
      klass = nil
      Dir.glob(directories).each do |dir|
        if File.directory?(dir)
          Dir.foreach(dir) do |file|
            next unless file =~ /(.+).yml$/
            custom_query_groups = $1
            definitions = YAML::load(File.read(File.join(dir,file)))
            custom_query_groups = [definitions.delete('groups') || definitions.delete('group') || custom_query_groups].flatten
            definitions.each do |klass,v|
              klass = Module.const_get(klass)
              raise ArgumentError.new("invalid class for CustomQueries (#{klass})") unless klass.ancestors.include?(QueryBuilder)
              @@custom_queries[klass] ||= {}
              custom_query_groups.each do |custom_query_group|
                @@custom_queries[klass][custom_query_group] ||= {}
                klass_queries = @@custom_queries[klass][custom_query_group]
                v.each do |k,v|
                  klass_queries[k] = v
                end
              end
            end
          end
        end
      end
    rescue NameError => err
      raise ArgumentError.new("invalid class for CustomQueries (#{klass})")
    end
    
    # Return the parser built from the query. The class of the returned object can be different
    # from the class used to call "new". For example: NodeQuery.new("comments from nodes in project") would
    # return a CommentQuery since that is the final fetched objects (final_parser).
    # 
    # ==== Parameters
    # query<String>:: Pseudo sql query string.
    # opts<Hash>:: List of options.
    #   * custom_query_group<String>:: Name of 'yaml' custom query to use (eg. 'test' for 'test.yml')
    #   * skip_after_parse<Boolean>::  If true, skip 'after_parse' method.
    #   * ignore_warnings<Boolean>::   If true, the query will always succeed (returns a dummy query instead of nil).
    #
    # ==== Returns
    # QueryBuilder:: A query builder subclass object.
    #   The object can be invalid if there were errors found during compilation.
    #
    # ==== Examples
    #   DummyQuery.new("objects in project order by name ASC, id DESC", :custom_query_group => 'test')
    #
    def new(query, opts = {})
      obj = super(query, opts)
      obj.final_parser
    end
  end
  
  # Build a new query from a pseudo sql string. See QueryBuilder::new for details.
  def initialize(query, opts = {})
    if opts[:pre_query]
      init_with_pre_query(opts[:pre_query], opts[:elements])
    else
      init_with_query(query, opts)
    end
    
    parse_elements(@elements)
  end
  
  # Convert query object to a string. This string should then be evaluated.
  #
  # ==== Parameters
  # type<Symbol>:: Type of query to build (:find or :count).
  #
  # ==== Returns
  # NilClass:: If the query is not valid and "ignore_warnings" was not set to true during initialize.
  # String::   A string representing the query with its bind parameters.
  #
  # ==== Examples
  # query.to_s
  # => "[\"SELECT objects.* FROM objects WHERE objects.project_id = ?\", project_id]"
  #
  # DummyQuery.new("nodes in site").to_s
  # => "\"SELECT objects.* FROM objects\""
  #
  # query.to_s(:count)
  # => "[\"SELECT COUNT(*) FROM objects WHERE objects.project_id = ?\", project_id]"
  def to_s(type = :find)
    return nil if !valid?
    return "\"SELECT #{main_table}.* FROM #{main_table} WHERE 0\"" if @tables.empty? # all alternate queries invalid and 'ignore_warnings' set.
    statement, bind_values = build_statement(type)
    bind_values.empty? ? "\"#{statement}\"" : "[#{[["\"#{statement}\""] + bind_values].join(', ')}]"
  end
  
  # Convert the query object into an SQL query.
  #
  # ==== Parameters
  # bindings<Binding>:: Binding context in which to evaluate bind clauses (query arguments).
  # type<Symbol>::      Type of SQL query (:find or :count)
  #
  # ==== Returns
  # NilClass:: If the query is not valid and "ignore_warnings" was not set to true during initialize.
  # String::   An SQL query, ready for execution (no more bind variables).
  #
  # ==== Examples
  # query.sql(binding)
  # => "SELECT objects.* FROM objects WHERE objects.project_id = 12489"
  #
  # query.sql(bindings, :count)
  # => "SELECT COUNT(*) FROM objects WHERE objects.project_id = 12489"
  def sql(bindings, type = :find)
    return nil if !valid?
    return "SELECT #{main_table}.* FROM #{main_table} WHERE 0" if @tables.empty? # all alternate queries invalid and 'ignore_warnings' set.
    statement, bind_values = build_statement(type)
    connection = get_connection(bindings)
    statement.gsub('?') { eval_bound_value(bind_values.shift, connection, bindings) }
  end
  
  
  # Test query validity
  #
  # ==== Returns
  # TrueClass:: True if object is valid.
  def valid?
    @errors == []
  end
  
  # Name of the pagination key when 'paginate' is used.
  #
  # ==== Parameters
  # parameters
  #
  # ==== Returns
  # String:: Pagination key name.
  #
  # ==== Examples
  # DummyQuery.new("objects in site limit 5 paginate pak").pagination_key
  # => "pak"
  def pagination_key
    @offset_limit_order_group[:paginate]
  end
  
  # Main class for the query (useful when queries move from class to class)
  #
  # ==== Returns
  # Class:: Class of element
  #
  # ==== Examples
  # DummyQuery.new("comments from nodes in project").main_class
  # => Comment
  def main_class
    Module.const_get(@@main_class[self.class])
  end
  
  protected
    
    def current_table
      @current_table || main_table
    end
    
    def main_table
      @main_table || @@main_table[self.class]
    end
  
    def parse_part(part, is_last)
      
      rest,   context = part.split(' in ')
      clause, filters = rest.split(/\s+where\s+/)
      
      if @just_changed_class
        # just changed class: parse filters && context
        parse_filters(filters) if filters
        @just_changed_class = false
        return nil
      elsif new_class = parse_change_class(clause, is_last)
        if context
          last_filter = @where.pop # pop/push is to keep queries in correct order (helps reading sql)
          parse_context(context, true)
          @where << last_filter
        end
        return new_class
      else
        add_table(main_table)
        parse_filters(filters) if filters
        parse_context(context, is_last) if context # .. in project
        parse_relation(clause, context)
        return nil
      end
    end
    
    def parse_filters(clause)
      # TODO: add 'match' parameter (#105)
      rest         = clause.strip
      types        = [:par_open, :value, :bool_op, :op, :par_close]
      allowed      = [:par_open, :value]
      after_value  = [:op, :bool_op, :par_close]
      par_count    = 0
      last_bool_op = ''
      has_or       = false
      res          = ""
      while rest != ''
        # puts rest.inspect
        if rest =~ /\A\s+/
          rest = rest[$&.size..-1]
          res << " "
        elsif rest[0..0] == '('
          unless allowed.include?(:par_open)
            @errors << clause_error(clause, rest, res) 
            return
          end
          res << '('
          rest = rest[1..-1]
          par_count += 1
        elsif rest[0..0] == ')'  
          unless allowed.include?(:par_close)
            @errors << clause_error(clause, rest, res) 
            return
          end
          res << ')'
          rest = rest[1..-1]
          par_count -= 1
          if par_count < 0
            @errors << clause_error(clause, rest, res)
            return
          end
          allowed = [:op, :bool_op]
        elsif rest =~ /\A((>=|<=|<>|\!=|<|=|>)|((not\s+like|like|lt|le|eq|ne|ge|gt)\s+))/
          unless allowed.include?(:op)
            @errors << clause_error(clause, rest, res) 
            return
          end
          op = $1.strip
          rest = rest[op.size..-1]
          op = {'lt' => '<', 'le' => '<=', 'eq' => '=', 'ne' => '<>', '!=' => '<>', 'ge' => '>=', 'gt' => '>', 'like' => 'LIKE', 'not like' => 'NOT LIKE'}[op] || $1
          res << op
          allowed = [:value, :par_open]
        elsif rest =~ /\A("|')([^\1]*?)\1/  
          unless allowed.include?(:value)
            @errors << clause_error(clause, rest, res) 
            return
          end
          rest = rest[$&.size..-1]
          res << map_literal($2)
          allowed = after_value
        elsif rest =~ /\A(\d+|[\w:]+)\s+(second|minute|hour|day|week|month|year)s?/
          unless allowed.include?(:value)
            @errors << clause_error(clause, rest, res) 
            return
          end
          rest = rest[$&.size..-1]
          fld, type = $1, $2
          unless field = field_or_attr(fld, table, :filter)
            @errors << "invalid field or value #{fld.inspect}"
            return
          end
          res << "INTERVAL #{field} #{type.upcase}"
          allowed = after_value
        elsif rest =~ /\A(-?\d+)/  
          unless allowed.include?(:value)
            @errors << clause_error(clause, rest, res) 
            return
          end
          rest = rest[$&.size..-1]
          res << $1
          allowed = after_value
        elsif rest =~ /\A(is\s+not\s+null|is\s+null)/
          unless allowed.include?(:bool_op)
            @errors << clause_error(clause, rest, res) 
            return
          end
          rest = rest[$&.size..-1]
          res << $1.upcase
          allowed = [:par_close, :bool_op]
        elsif rest[0..7] == 'REF_DATE'  
          unless allowed.include?(:value)
            @errors << clause_error(clause, rest, res) 
            return
          end
          rest = rest[8..-1]
          res << @ref_date
          allowed = after_value
        elsif rest =~ /\A(\+|\-)/  
          unless allowed.include?(:op)
            @errors << clause_error(clause, rest, res) 
            return
          end
          rest = rest[$&.size..-1]
          res << $1
          allowed = [:value, :par_open]
        elsif rest =~ /\A(and|or)/
          unless allowed.include?(:bool_op)
            @errors << clause_error(clause, rest, res) 
            return
          end
          rest = rest[$&.size..-1]
          res << $1.upcase
          has_or ||= $1 == 'or'
          allowed = [:par_open, :value]
        elsif rest =~ /\A[\w:]+/
          unless allowed.include?(:value)
            @errors << clause_error(clause, rest, res) 
            return
          end
          rest = rest[$&.size..-1]
          fld = $&
          unless field = field_or_attr(fld, table, :filter)
            @errors << "invalid field or value #{fld.inspect}"
            return
          end
          res << field
          allowed = after_value
        else  
          @errors << clause_error(clause, rest, res)
          return
        end
      end
      
      if par_count > 0
        @errors << "invalid clause #{clause.inspect}: missing closing ')'"
      elsif allowed.include?(:value)
        @errors << "invalid clause #{clause.inspect}"
      else
        @where << (has_or ? "(#{res})" : res)
      end
    end
    
    def parse_order_clause(order)
      return @order unless order
      res = []
      
      order.split(',').each do |clause|
        if clause == 'random'
          res << "RAND()"
        else
          if clause =~ /^\s*([^\s]+) (ASC|asc|DESC|desc)/
            fld_name, direction = $1, $2
          else
            fld_name = clause
            direction = 'ASC'
          end
          if fld = field_or_attr(fld_name, table, :order)
            res << "#{fld} #{direction.upcase}"
          elsif fld.nil?
            @errors << "invalid field '#{fld_name}'"
          end
        end
      end
      res == [] ? nil : " ORDER BY #{res.join(', ')}"
    end
    
    def parse_group_clause(group)
      return @group unless group
      res = []
      
      group.split(',').each do |field|
        if fld = map_field(field, table, :group)
          res << fld
        else
          @errors << "invalid field '#{field}'"
        end
      end
      res == [] ? nil : " GROUP BY #{res.join(', ')}"
    end
    
    def parse_limit_clause(limit)
      return @limit unless limit
      if limit.kind_of?(Fixnum)
        " LIMIT #{limit}"
      elsif limit =~ /^\s*(\d+)\s*,\s*(\d+)/
        @offset = " OFFSET #{$1}"
        " LIMIT #{$2}"
      elsif limit =~ /(\d+)/
        " LIMIT #{$1}"
      else
        @errors << "invalid limit clause '#{limit}'"
        nil
      end
    end
    
    def parse_paginate_clause(paginate)
      return @offset unless paginate
      if !@limit
        # TODO: raise error ?
        @errors << "invalid paginate clause '#{paginate}' (used without limit)"
        nil
      elsif (fld = map_literal(paginate, :ruby)) && (page_size = @limit[/ LIMIT (\d+)/,1])
        @page_size = [2,page_size.to_i].max
        " OFFSET #{insert_bind("((#{fld}.to_i > 0 ? #{fld}.to_i : 1)-1)*#{@page_size}")}"
      else
        @errors << "invalid paginate clause '#{paginate}'"
        nil
      end
    end
    
    def parse_offset_clause(offset)
      return @offset unless offset
      if !@limit
        # TODO: raise error ?
        @errors << "invalid offset clause '#{offset}' (used without limit)"
        nil
      elsif offset.strip =~ /^\d+$/
        " OFFSET #{offset}"
      else
        @errors << "invalid offset clause '#{offset}'"
        nil
      end
    end
    
    def add_table(use_name, table_name = nil)
      table_name ||= use_name
      if !@table_counter[use_name]
        @table_counter[use_name] = 0
        if use_name != table_name
          @tables << "#{table_name} as #{use_name}"
        else
          @tables << table_name
        end
      else  
        @table_counter[use_name] += 1
        @tables << "#{table_name} AS #{table(use_name)}"
      end
    end
    
    # return a unique table name for the current sub-query context, adding the table when necessary
    def needs_table(table1, table2, filter)
      @needed_tables[table2] ||= {}
      @needed_tables[table2][table] ||= begin
        add_table(table2)
        @where << filter.gsub('TABLE1', table).gsub('TABLE2', table(table2))
        table(table2)
      end
    end
    
    # versions LEFT JOIN dyn_attributes ON ...
    def needs_join_table(table1, type, table2, clause, join_name = nil)
      join_name ||= "#{table1}=#{type}=#{table2}"
      @needed_join_tables[join_name] ||= {}
      @needed_join_tables[join_name][table] ||= begin
        # define join for this part ('table' = unique for each part)
        
        first_table = table(table1)
        
        if !@table_counter[table2]
          @table_counter[table2] = 0
          second_table  = table2
        else
          @table_counter[table2] += 1
          second_table  = "#{table2} AS #{table(table2)}"
        end
        @join_tables[first_table] ||= []
        @join_tables[first_table] << "#{type} JOIN #{second_table} ON #{clause.gsub('TABLE1',table(table1)).gsub('TABLE2',table(table2))}"
        table(table2)
      end
    end
    
    def table_counter(table_name)
      @table_counter[table_name] || 0
    end
    
    def table_at(table_name, index)
      if index < 0
        return nil # no table at this address
      end
      index == 0 ? table_name : "#{table_name[0..1]}#{index}"
    end
    
    def table(table_name=main_table, index=0)
      table_at(table_name, table_counter(table_name) + index)
    end
    
    def merge_alternate_queries(alt_queries)
      counter = 1
      if valid?
        counter = 1
      else
        if @ignore_warnings
          # reset current query
          @tables   = []
          @join_tables = {}
          @where  = []
          @errors   = []
          @distinct = nil
        end
        counter = 0
      end
      
      if @where.compact == []
        where_list = []
      else
        where_list = [@where.compact.reverse.join(' AND ')]
      end
      
      alt_queries.each do |query|
        next unless query.main_class == self.main_class # no mixed class target !
        @errors += query.errors unless @ignore_warnings
        next unless query.valid?
        query.where.compact!
        next if query.where.empty?
        counter += 1
        merge_tables(query)
        @distinct ||= query.distinct
        where_list << query.where.reverse.join(' AND ')
      end
      
      @where_list = where_list
      
      @tables.uniq!
      
      fix_where_list(where_list)
      
      if counter > 1
        @distinct = @tables.size > 1
        @where  = ["((#{where_list.join(') OR (')}))"]
      else
        @where  = where_list
      end
    end
    
    def merge_tables(sub_query)
      @tables += sub_query.tables
      sub_query.join_tables.each do |k,v|
        @join_tables[k] ||= []
        @join_tables[k] << v
      end
    end
    
    def prepare_custom_query_arguments(key, value)
      if value.kind_of?(Array)
        value.map {|e| parse_custom_query_argument(key, e)}
      elsif value.kind_of?(Hash)
        value.each do |k,v|
          if v.kind_of?(Array)
            value[k] = v.map {|e| parse_custom_query_argument(key, e)}
          else
            value[k] = parse_custom_query_argument(key, v)
          end
        end
      else
        parse_custom_query_argument(key, value)
      end
    end
    
    # Map a field to be used inside a query. An attr is a field from table at index 0 = @node attribute.
    def field_or_attr(fld, table_name = table, context = nil)
      if fld =~ /^\d+$/
        return fld
      elsif !(list = @select.select {|e| e =~ /\A#{fld}\Z|AS #{fld}|\.#{fld}\Z/}).empty?
        res = list.first
        if res =~ /\A(.*) AS #{fld}\Z/
          res = $1
        end
        return context == :filter ? "(#{res})" : res
      elsif table_name
        map_field(fld, table_name, context)
      else
        map_attr(fld)
      end
    end
    
    def build_statement(type = :find)
      statement = type == :find ? find_statement : count_statement

      # get bind variables
      bind_values = []
      statement.gsub!(/\[\[(.*?)\]\]/) do
        bind_values << $1
        '?'
      end
      [statement, bind_values]
    end
    
    def find_statement
      table_list = []
      @tables.each do |t|
        table_name = t.split(/\s+/).last # objects AS ob1
        if joins = @join_tables[table_name]
          table_list << "#{t} #{joins.join(' ')}"
        else
          table_list << t
        end
      end

      group = @group
      if !group && @distinct
        group = @tables.size > 1 ? " GROUP BY #{table}.id" : " GROUP BY id"
      end


      "SELECT #{@select.join(',')} FROM #{table_list.flatten.join(',')}" + (@where == [] ? '' : " WHERE #{@where.reverse.join(' AND ')}") + group.to_s + @order.to_s + @limit.to_s + @offset.to_s
    end
    
    def count_statement
      table_list = []
      @tables.each do |t|
        table_name = t.split(/\s+/).last # objects AS ob1
        if joins = @join_tables[table_name]
          table_list << "#{t} #{joins.join(' ')}"
        else
          table_list << t
        end
      end

      if @group =~ /GROUP\s+BY\s+(.+)/
        # we need to COALESCE in order to count groups where $1 is NULL.
        fields = $1.split(",").map{|f| "COALESCE(#{f.strip},0)"}.join(",")
        count_on = "COUNT(DISTINCT #{fields})"
      elsif @distinct
        count_on = "COUNT(DISTINCT #{table}.id)"
      else
        count_on = "COUNT(*)"
      end

      "SELECT #{count_on} FROM #{table_list.flatten.join(',')}" + (@where == [] ? '' : " WHERE #{@where.reverse.join(' AND ')}")
    end
    
    # Adapted from Rail's ActiveRecord code. We need "eval" because
    # QueryBuilder is a compiler and it has absolutely no knowledge
    # of the running context.
    def eval_bound_value(value_as_string, connection, bindings)
      value      = eval(value_as_string, bindings)
      if value.respond_to?(:map) && !value.kind_of?(String) #!value.acts_like?(:string)
        if value.respond_to?(:empty?) && value.empty?
          connection.quote(nil)
        else
          value.map { |v| connection.quote(v) }.join(',')
        end
      else
        connection.quote(value)
      end
    end

    def get_connection(bindings)
      eval "#{main_class}.connection", bindings
    end

    # ******** Overwrite these **********
    def class_from_table(table_name)
      Object
    end
    
    def default_context_filter
      raise NameError.new("default_context_filter not defined for class #{self.class}")
    end
    
    # Default sort order
    def default_order_clause
      nil
    end
    
    def after_parse
      # do nothing
    end
    
    def parse_change_class(rel, is_last)
      nil
    end
    
    def parse_relation(clause, context)
      return nil
    end
    
    def context_filter_fields(clause, is_last = false)
      nil
    end
    
    def parse_context(clause, is_last = false)
      
      if fields = context_filter_fields(clause, is_last)
        @where << "#{field_or_attr(fields[0])} = #{field_or_attr(fields[1], table(main_table,-1))}" if fields != :void
      else
        @errors << "invalid context '#{clause}'"
      end
    end
    
    # Map a litteral value to be used inside a query
    def map_literal(value, env = :sql)
      env == :sql ? insert_bind(value.inspect) : value
    end
    
    
    # Overwrite this and take car to check for valid fields.
    def map_field(fld, table_name, context = nil)
      if fld == 'id'
        "#{table_name}.#{fld}"
      else
        # TODO: error, raise / ignore ?
      end
    end
    
    def map_attr(fld)
      insert_bind(fld.to_s)
    end
    
    # ******** And maybe overwrite these **********
    def parse_custom_query_argument(key, value)
      return nil unless value
      value = value.gsub('REF_DATE', @ref_date)
      case key
      when :order
        " ORDER BY #{value}"
      when :group
        " GROUP BY #{value}"
      else
        value
      end
    end
    
    def extract_custom_query(list)
      list[-1].split(' ').first
    end
    
  private
    
    def parse_elements(elements)
      # "final_parser" is the parser who will respond to 'to_sql'. It might be a sub-parser for another class.
      @final_parser = self
      
      if @@custom_queries[self.class] && 
         @@custom_queries[self.class][@opts[:custom_query_group]] && 
         custom_query = @@custom_queries[self.class][@opts[:custom_query_group]][extract_custom_query(elements)]
        custom_query.each do |k,v|
         instance_variable_set("@#{k}", prepare_custom_query_arguments(k.to_sym, v))
        end
        # set table counters
        @tables.each do |t|
          base, as, tbl = t.split(' ')
          @table_counter[base] ||= 0
          @table_counter[base] += 1 if tbl
        end
        # parse filters
        clause, filters = elements[-1].split(/\s+where\s+/)

        parse_filters(filters) if filters
        
        @limit  = parse_limit_clause(@offset_limit_order_group[:limit])
        if @offset_limit_order_group[:paginate]
          @offset = parse_paginate_clause(@offset_limit_order_group[:paginate])
        else
          @offset = parse_offset_clause(@offset_limit_order_group[:offset])
        end
        
        @order = parse_order_clause(@offset_limit_order_group[:order])
      else
        i, new_class = 0, nil
        elements.each_index do |i|
          break if new_class = parse_part(elements[i], i == 0) # yes, is_last is first (parsing reverse)
        end
        
        if new_class
          # move to another parser class
          @final_parser = new_class.new(nil, :pre_query => self, :elements => elements[i..-1])
        else
          @distinct ||= elements.size > 1
          @select << "#{table}.*"

          merge_alternate_queries(@alt_queries) if @alt_queries

          @limit  = parse_limit_clause(@offset_limit_order_group[:limit])
          if @offset_limit_order_group[:paginate]
            @offset = parse_paginate_clause(@offset_limit_order_group[:paginate])
          else
            @offset = parse_offset_clause(@offset_limit_order_group[:offset])
          end


          @group = parse_group_clause(@offset_limit_order_group[:group])
          @order = parse_order_clause(@offset_limit_order_group[:order] || default_order_clause)
        end
      end

      if @final_parser == self
        after_parse unless @opts[:skip_after_parse]
        @where.compact!
      end
    end
    
    def init_with_query(query, opts)
      @opts = opts
      
      if query.kind_of?(Array)
        @query = query[0]
        if query.size > 1
          @alt_queries = query[1..-1].map {|q| self.class.new(q, opts.merge(:skip_after_parse => true))}
        end
      else
        @query = query
      end
      
      
      @offset_limit_order_group = {}
      if @query == nil || @query == ''
        elements = [main_table]
      else
        elements = @query.split(' from ')
        last_element = elements.last
        last_element, @offset_limit_order_group[:offset] = last_element.split(' offset ')
        last_element, @offset_limit_order_group[:paginate] = last_element.split(' paginate ')
        last_element, @offset_limit_order_group[:limit]  = last_element.split(' limit ')
        last_element, @offset_limit_order_group[:order]  = last_element.split(' order by ')
        elements[-1], @offset_limit_order_group[:group]  = last_element.split(' group by ')
      end
      
      @offset_limit_order_group[:limit] = opts[:limit] || @offset_limit_order_group[:limit]
      # In order to know the table names of the dependencies, we need to parse it backwards.
      # We first find the closest elements, then the final ones. For example, "pages from project" we need
      # project information before getting 'pages'. 
      @elements = elements.reverse

      @tables  = []
      @join_tables = {}
      @table_counter  = {}
      @where          = []
      # list of tables that need to be added for filter clauses (should be added only once per part)
      @needed_tables = {}
      # list of tables that need to be added through a join (should be added only once per part)
      @needed_join_tables = {}

      @errors  = []

      @select  = []

      @ignore_warnings = opts[:ignore_warnings]

      @ref_date = opts[:ref_date] ? "'#{opts[:ref_date]}'" : 'now()'
    end

    def init_with_pre_query(pre_query, elements)
      pre_query.instance_variables.each do |iv|
        next if iv == '@query' || iv == '@final_parser'
        instance_variable_set(iv, pre_query.instance_variable_get(iv))
      end
      @just_changed_class = true
      @elements = elements
    end
    
    def clause_error(clause, rest, res)
      "invalid clause #{clause.inspect} near \"#{res[-2..-1]}#{rest[0..1]}\""
    end
    
    def insert_bind(str)
      "[[#{str}]]"
    end
    
    # Make sure all clauses are compatible (where_list is a list of strings, not arrays)
    def fix_where_list(where_list)
      # do nothing
    end
end
