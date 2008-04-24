=begin
icons from nodes from project

SELECT nd1.id, nd1.project_id, nd1.name, nd1.kpath FROM nodes as nd1, links AS lk1, nodes as nd2 WHERE (lk1.relation_id = 4 AND lk1.target_id = nd1.id AND lk1.source_id = nd2.id) AND (nd2.project_id = 11)
=end
require 'rubygems'

if false
  require 'ruby-debug'
  Debugger.start
end

class QueryBuilder
  attr_reader :tables, :filters
  @@main_table = 'objects'
  
  class << self
    def set_main_table(table_name)
      @@main_table = table_name.to_s
    end
  end
  
  def initialize(query)
    @query   = query
    @tables  = []
    @table_counter = {}
    @filters = []
    @main_table ||= 'objects'
    if @query == nil || @query == ''
      elements = [main_table]
    else
      elements = @query.split(' from ')
      elements[-1], order = elements[-1].split(' order by ')
    end
    
    parts = []
    last_was_context = true
    
    elements.each_index do |i|
      e = elements[i]
      used_as_context = false
      if context_clause?(e) && !last_was_context
        # merge contextual clause into last part
        parts[-1] << e
        used_as_context = true
      else
      
        #if (i != elements.size - 1) || !used_as_context
        clause, filters = e.split(/\s+where\s+/)
        parts << [clause, filters]
      end
      last_was_context = used_as_context
    end
    
    # In order to know the table names of the dependencies, we need to parse it backwards.
    # We first find the closest elements, then the final ones. For example, "pages from project" we need
    # project information before getting 'pages'. 
    parts.reverse!
    
    parts.each do |e|
      e << default(e[0]) unless e.size > 2
      
      add_table(main_table)
      parse_part(e)
    end
    
    @order = parse_order_clause(order)
    
    after_parse
    @filters.compact!
  end
  
  def to_sql
    "SELECT #{table}.* FROM #{@tables.join(',')}" + (@filters == [] ? '' : " WHERE #{@filters.reverse.join(' AND ')}#{@order}#{@limit}")
  end
  
  protected
    
    def main_table
      @@main_table
    end
  
    def parse_part(part)
      clause, filters, context_filter = *part
      
      parse_filters(filters) if filters
      @filters << context_filter(context_filter) if context_filter
      @filters << relation(clause)
    end
    
    def parse_filters(txt)
      txt.split(/\s+and\s+/).each do |clause|
        # [field] [=|>]
        if clause =~ /("[^"]*"|'[^']*'|\w+)\s*(like|is not|is|>=|<=|<>|<|=|>|lt|le|eq|ne|ge|gt)\s*("[^"]*"|'[^']*'|\w+)/
          # TODO: add 'match' parameter (#105)
          parts = [$1,$3]
          op = {'lt' => '<','le' => '<=','eq' => '=','ne' => '<>','ge' => '>=','gt' => '>'}[$2] || $2
          parts.map! do |part|
            if ['"',"'"].include?(part[0..0])
              map_literal(part[1..-2])
            elsif part == 'null'
              "NULL"
            else
              field_or_param(part)
            end
          end.compact!
          
          if parts.size == 2 && parts[0] != 'NULL'
            # ok, no value/field error
            if op[0..2] == 'is' && parts[1] != 'NULL'
              # error
            else
              @filters << parts.join(" #{op.upcase} ")
            end
          else
            # TODO: value/field error
          end
        else
          # invalid clause format
        end
      end
    end
    
    def parse_order_clause(order)
      return '' unless order
      res = []
      
      order.split(',').each do |clause|
        if clause =~ /^(\w+) (ASC|asc|DESC|desc)$/
          fld_name, direction = $1, $2
          if fld = map_field(fld_name, table)
            res << "#{@tables.size == 1 ? fld_name : fld} #{direction.upcase}"
          else
            # TODO: raise error ?
            puts "BAD field #{fld_name}"
          end
        elsif clause == 'random'
          res << "RAND()"
        else
          # TODO: raise error ?
          puts "bad order clause #{clause}"
        end
      end
      res == [] ? '' : " ORDER BY #{res.join(', ')}"
    end
    
    def add_table(table_name)
      if !@table_counter[table_name]
        @tables << table_name
        @table_counter[table_name] = 0
      else  
        @table_counter[table_name] += 1
        @tables << "#{table_name} AS #{table(table_name)}"
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
    
    # ******** Overwrite these **********
    def default(clause)
      nil
    end
    
    def after_parse
      # do nothing
    end
    
    def relation(clause)
      return nil
    end
    
    def context_clause?(clause)
      false
    end
    
    def context_filter_fields(clause)
      nil
    end
    
    def context_filter(clause)
      if fields = context_filter_fields(clause)
        "#{field_or_param(fields[0])} = #{field_or_param(fields[1], table(main_table,-1))}"
      else
        nil
      end
    end
    
    # Map a litteral value to be used inside a query
    def map_literal(value)
      value.inspect
    end
    
    # Map a field to be used inside a query
    def field_or_param(fld, table_name = table)
      if table_name
        map_field(fld, table_name)
      else
        map_parameter(fld)
      end
    end
    
    # Overwrite this and take car to check for valid fields.
    def map_field(fld, table_name)
      if fld == 'id'
        "#{table_name}.#{fld}"
      else
        # TODO: error, raise / ignore ?
      end
    end
    
    def map_parameter(fld)
      fld.to_s.upcase
    end
end