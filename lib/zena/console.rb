module Zena
  module Console
    include Zena::Acts::Secure

    def self.included(base)
      if base == Object
        raise %q{You should not include Zena::Console directly in Object. Use this instead: class << self; include Zena::Console; end
}
      end
    end

    def err(obj)
      obj.errors.each_error do |er,msg|
        puts "[#{er}] #{msg}"
      end
    end

    # FIXME: DOCUMENT
    def create(attrs)
      secure(Node) { Node.create_node(Node.transform_attributes(attrs)) }
    end

    def field_to_prop(list, native_key, prop_key)
      list = find(list) if list.kind_of?(String)
      list.each do |rec|
        next unless value = rec[native_key]
        if rec.kind_of?(Node)
          elems = rec.visible_versions
        else
          elems = [rec]
        end
        elems.each do |rec|
          prop  = rec.prop
          prop[prop_key] = value
          Zena::Db.execute "UPDATE #{rec.class.table_name} SET properties=#{Zena::Db.quote(rec.class.encode_properties(prop))} WHERE id=#{rec[:id]}"
        end
      end
    end

    def set_prop(list, key, value)
      list = find(list) if list.kind_of?(String)
      list.each do |rec|
        if rec.kind_of?(Node)
          elems = rec.visible_versions
        else
          elems = [rec]
        end
        elems.each do |rec|
          prop  = rec.prop
          prop[key] = value
          Zena::Db.execute "UPDATE #{rec.class.table_name} SET properties=#{Zena::Db.quote(rec.class.encode_properties(prop))} WHERE id=#{rec[:id]}"
        end
      end
    end

    def rename_prop(pseudo_sql, old_key, new_key)
      count = 0
      foreach(pseudo_sql) do |node|
        node.versions.each do |rec|
          count += 1
          prop  = rec.prop
          value = prop.delete(old_key)
          if !value.blank?
            prop[new_key] = value
            Zena::Db.execute "UPDATE #{rec.class.table_name} SET properties=#{Zena::Db.quote(rec.class.encode_properties(prop))} WHERE id=#{rec[:id]}"
          end
        end
      end
      "Renamed '#{old_key}' to '#{new_key}' in #{count} versions"
    end

    # Transform every value of a given property by using a block with |node, old_value| and
    # returning the new value.
    def change_prop(pseudo_sql, key)
      count = 0
      unless block_given?
        puts "You need to provide a block |node, old_value| and return the new value"
        return
      end
      foreach(pseudo_sql) do |node|
        node.versions.each do |v|
          count += 1
          prop = v.prop
          val  = prop[key]
          new_val = yield(node, val)
          unless new_val == val
            if new_val
              prop[key] = new_val
            else
              prop.delete(key)
            end
            Zena::Db.execute "UPDATE #{v.class.table_name} SET properties=#{Zena::Db.quote(v.class.encode_properties(prop))} WHERE id=#{v[:id]}"
          end
        end
      end
      "Changed '#{key}' prop in #{count} versions"
    end

    def login(name, host = nil)
      finder = {}
      finder[:conditions] = cond = [[]]
      if host
        finder[:joins] = 'INNER JOIN sites ON sites.id = users.site_id'
        cond.first << 'sites.host = ?'
        cond << host.to_s
      end

      cond.first << 'users.login = ?'
      cond << name.to_s
      cond[0] = cond.first.join(' AND ')
      if visitor = User.find(:first, finder)
        Thread.current[:visitor] = visitor
        puts "Logged #{visitor.login} in #{visitor.site.host}"
      else
        raise ActiveRecord::RecordNotFound
      end
    rescue ActiveRecord::RecordNotFound
      puts "Could not login with user name: #{name}"
    end

    def nodes(zip_or_name)
      if zip_or_name.kind_of?(Fixnum)
        secure(Node) { Node.find_by_zip(zip_or_name) }
      else
        secure(Node) { Node.find_by_title(zip_or_name) }
      end
    end

    # Usage:
    # find('contacts in site')
    # find(:all, 'contacts in site') # same as above
    # find(:qb => 'contacts in site', :_find => :all) # same as above
    def find(count_or_query, pseudo_sql = nil, opts = {})
      if count_or_query.kind_of?(Hash)
        query = count_or_query
      elsif count_or_query.kind_of?(Fixnum)
        query = {:qb => "node where id = #{count_or_query} in site", :_find => :first}
      elsif pseudo_sql.nil?
        query = {:qb => count_or_query}
      else
        query = {:qb => pseudo_sql, :_find => count_or_query}
      end
      query[:_find] ||=
      count = Node.plural_relation?(query[:qb].split(' ').first) ? :all : :first

      nodes = secure(Node) do
        Node.search_records(query,
          :node => current_site.root_node,
          :default => {:scope => 'site'}
        )
      end
    end

    def count(pseudo_sql, opts = {})
      node  = opts.delete(:node) || current_site.root_node
      options = {:errors => true, :rubyless_helper => self, :default => {:scope => 'site'}}

      count = node.find(:count, pseudo_sql, options)

      if count.kind_of?(::QueryBuilder::Error)
        puts "Error parsing query #{pseudo_sql.inspect} (#{count.message})"
        return nil
      else
        return count
      end
    end

    def foreach(pseudo_sql, opts = {})
      limit = 100

      return nil unless block_given?
      node    = opts.delete(:node) || current_site.root_node
      options = {:errors => true, :rubyless_helper => self, :default => {:scope => 'site'}}

      count = node.find(:count, pseudo_sql, options)

      if count.kind_of?(::QueryBuilder::Error)
        puts "Error parsing query #{pseudo_sql.inspect} (#{count.message})"
        return nil
      end

      begin
        query = Node.build_query(:all, pseudo_sql,
          :node_name       => 'self',
          :main_class      => VirtualClass['Node'],
          :rubyless_helper => self,
          :default         => options[:default]
        )
      rescue ::QueryBuilder::Error => err
        puts "Error parsing query #{pseudo_sql.inspect} (#{err.message})"
        return nil
      end


      query.limit  = " LIMIT #{limit}"

      page_count = (count.to_f / limit).ceil
      puts "#{count} nodes, #{page_count} chunk(s) (100 items)"
      curr_page  = 1
      # We walk pages in reverse order in case objects are deleted
      
      for curr_page in (1..page_count).to_a.reverse
        query.offset = " OFFSET #{limit * (curr_page - 1)}"
        if list = Node.do_find(:all, eval(query.to_s(:find)))
          puts "Page #{curr_page}/#{page_count}"
          list.each do |record|
            yield(record)
          end
        end
      end
      nil
    end

    def profile(node_id)
      require 'ruby-prof'
      ctrl = NodesController.new
      ctrl.request = Struct.new(:format).new(Mime::HTML)
      ctrl.instance_variable_set(:@node, nodes(node_id))
      start = Time.now
      result = RubyProf.profile do
        yield(ctrl)
      end
      puts(Time.now - start)
      File.open('grind.log', 'wb') do |f|
        RubyProf::CallTreePrinter.new(result).print(f)
      end
    end
  end # Console
end # Zena