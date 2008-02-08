module Zena
  module WebDav
    
    private
      def mkcol_for_path(path)
      end
      
      def write_content_to_path(path, content)
        puts "WRITE:#{path}"
        node = get_node_for_path(path)
        puts "NODE_WRITE: #{node.name}"
        if node
          # update
          node.update_attributes(:v_text => content)
        else
          # create
          parent_path = path.split('/')[0..-2]
          parent = secure!(Node) { Node.find_by_path(parent_path.join('/')) }
          node   = secure!(Page) { Page.create(:parent_id => parent[:id], :name => path.split('/').last, :v_text => content ) }
        end
      end
      
      def copy_to_path(resource, dest_path, depth)
        resource.copy!(dest_path, depth)
      end
      
      def move_to_path(resource, dest_path, depth)
        resource.move!(dest_path, depth)
      end
      
      def get_resource_for_path(path)
        ZenaNodeResource.new(get_node_for_path(path))
      end
      
      def get_node_for_path(path)
        raise WebDavErrors::NotFoundError if path =~ /\.DS_Store/
        puts "FIND: #{path.inspect}"
        return visitor.site.root_node if path.blank? or path.eql?("/")
        if path =~ /(.*)\./
          node = secure!(Node) { Node.find_by_path($1) }
        else
          node = secure!(Node) { Node.find_by_path(path) }
        end  
        raise WebDavErrors::NotFoundError if node.nil?
        node
      rescue ActiveRecord::RecordNotFound
        raise WebDavErrors::NotFoundError
      end
  end
end

class ZenaNodeResource
  attr_accessor :node
  include Zena::Acts::Secure
  include WebDavResource
  def visitor
    @node.visitor
  end
  
  def initialize(node)
    @node   = node
  end
  
  def displayname
    if @node.kind_of?(Note)
      @node.name + '.txt'
    elsif @node.kind_of?(Document)
      @node.name + '.' + @node.c_ext
    else
      @node.name
    end
  end
  
  def href
    return '/' if @node.fullpath.blank?
    '/' + (@node.fullpath.split('/')[0..-2] + [self.displayname]).join('/')
  end

  def delete!
    # FIXME
  end

  def move! (dest_path, depth)
    parent_path = dest_path.split('/')[0..-2]
    parent = secure!(Node) { Node.find_by_path(parent_path.join('/')) }
    raise WebDavErrors::ConflictError unless @node.update_attributes(:parent_id => parent[:id])
  rescue ActiveRecord::RecordNotFound
    raise WebDavErrors::ForbiddenError
  end

  def copy! (dest_path, depth)
    # FIXME
  end

  def status
    gen_status(200, "OK").to_s
  end

  def collection?
    return !@node.kind_of?(Document) && !@node.kind_of?(Note)
  end

  def children
    res = (@node.children || []).map { |p| ZenaNodeResource.new(p) }
    puts "CHILDREN OF #{@node.fullpath}: #{res.map { |r| r.get_href }.inspect }"
    
    res
  end

  def set_displayname(value)
    if @node.update_attributes(:name => value)
     gen_status(200, "OK").to_s
    else
      gen_status(409, "Conflict").to_s
    end
  end

  def creationdate
    @node.created_at.httpdate
  end

  def getlastmodified
    @node.updated_at.httpdate
  end

  def set_getlastmodified(value)
    if @node.update_attributes(:updated_at => value)
      gen_status(200, "OK").to_s
    else
      gen_status(409, "Conflict").to_s
    end
  end

  # ???
  def getetag
     # ??sprintf('%x-%x-%x', @st.ino, @st.size, @st.mtime.to_i) unless @file.nil?
  end

  def getcontenttype
    if @node.kind_of?(Note)
      "text/plain"
    elsif @node.kind_of?(Document)
      @node.c_content_type
    else
      "httpd/unix-directory"
    end
  end

  def getcontentlength
    if @node.kind_of?(Note)
      @node.v_text.length
    elsif @node.kind_of?(Document)
      s = @node.c_file.stat.size
      puts "SIZE #{@node.name} = #{s}"
      s
    else
      0
    end
  end

  def data
    if @node.kind_of?(Note)
      @node.v_text
    elsif @node.kind_of?(Document)
      f = @node.c_file
      puts f
      f
    else
      0
    end
  end
end
