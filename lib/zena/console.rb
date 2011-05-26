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

    def rename_prop(list, old_key, new_key)
      if list.first.kind_of?(Node)
        list = list.map(&:visible_versions).flatten
      end
      list.each do |rec|
        prop  = rec.prop
        if value = prop.delete(old_key)
          prop[new_key] = value
          Zena::Db.execute "UPDATE #{rec.class.table_name} SET properties=#{Zena::Db.quote(rec.class.encode_properties(prop))} WHERE id=#{rec[:id]}"
        end
      end
    end

    def field_to_prop(list, native_key, prop_key)
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

    def find(query)
      default_scope = 'site'
      query = {:qb => query} unless query.kind_of?(Hash)
      query[:_find] = Node.plural_relation?(method.split(' ').first) ? :all : :first
      nodes = secure(Node) { Node.search_records(query, :node => current_site.root_node, :default => {:scope => default_scope}) }
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
      for curr_page in (1..page_count)
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
  end # Console
end # Zena