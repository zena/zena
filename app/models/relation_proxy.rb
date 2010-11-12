class RelationProxy < Relation
  attr_accessor   :side, :link_errors, :start, :other_link, :last_target
  LINK_ATTRIBUTES = Zena::Use::Relations::LINK_ATTRIBUTES
  LINK_ATTRIBUTES_SQL = LINK_ATTRIBUTES.map {|sym| connection.quote_column_name(sym)}.join(',')
  LINK_SELECT     = "nodes.*,links.id AS link_id,#{LINK_ATTRIBUTES.map {|l| "links.#{l} AS l_#{l}"}.join(',')}"

  class << self

    # Find a role from a name. If a source_kpath is provided, only roles that could be reached
    # from this class are found.
    def find_by_role(role, source_kpath = nil)
      if source_kpath
        klasses = []
        source_kpath.split(//).each_index { |i| klasses << source_kpath[0..i] }
        rel = find(:first, :conditions => ["((source_role = ? AND target_kpath IN (?)) OR (target_role = ? AND source_kpath IN (?))) AND site_id = ?", role, klasses, role, klasses, current_site[:id]])
      else
        rel = find(:first, :conditions => ["(source_role = ? OR target_role = ?) AND site_id = ?", role, role, current_site[:id]])
      end

      return nil unless rel

      if rel[:target_role] == role
        rel.side = :source
      else
        rel.side = :target
      end

      rel
    end

    # Find a relation proxy for a role through a given node.
    # The finder makes sure the class path is compatible with the node's class/virtual_class given as parameter.
    def get_proxy(node, role)
      # TODO: use find_by_role(role, node.kpath) when all tests are clear
      rel = find_by_role(role)
      if rel && (node.new_record? || node.vclass.kpath =~ /\A#{rel.this_kpath}/)
        rel.start = node
        rel
      else
        # invalid relation for the given class path
        nil
      end
    end
  end

  # Define the caller's side. Changes the relation into a proxy so we can add/remove links. This sets the caller on the source side of the relation.
  def source=(start)
    @start = start
    @side  = :source
  end

  # Define the caller's side. Changes the relation into a proxy so we can add/remove links. This sets the caller on the target side of the relation.
  def target=(start)
    @start = start
    @side  = :target
  end

  # When a ...-to-many node is loaded and we modify it, focus on this specific node. For example:
  # calendar_status does not make sense (there can be many calendars). But if we focus on a specific
  # calendar, we then get the status for this particular link.
  def other_link=(link)
    return unless link[:relation_id] == self[:id]
    @other_link = link
  end

  # get

  def other_link
    other_links ? other_links[0] : nil
  end

  def other_id
    other_link ? other_link[other_side] : nil
  end

  def other_zip
    other_zips ? other_zips.first : nil
  end

  def other_ids
    (other_links || []).map { |l| l[other_side] }
  end

  def other_zips
    return nil unless @start[:id]
    return @other_zips if defined?(@other_zips)
    @other_zips = @records ? @records.map { |r| r.zip} : Zena::Db.fetch_ids("SELECT zip FROM nodes INNER JOIN links ON nodes.id=links.#{other_side} AND links.relation_id = #{self[:id]} AND links.#{link_side} = #{@start[:id]} WHERE #{secure_scope('nodes')} GROUP BY nodes.zip", 'zip')
  end

  def records(opts = {})
    return nil unless @start[:id]
    return @records if defined?(@records)
    options = {
      :select => "nodes.*, #{LINK_SELECT}",
      :joins => "INNER JOIN links ON nodes.id=links.#{other_side} AND links.relation_id = #{self[:id]} AND links.#{link_side} = #{@start[:id]}"
    }.merge(opts)
    @records = secure(Node) { Node.find(:all, options) }
  end

  LINK_ATTRIBUTES.each do |sym|
    define_method(sym) do
      other_link ? other_link[sym] : nil
    end
  end

  def other_role
    @side == :source ? self[:target_role] : self[:source_role]
  end

  def this_role
    @side == :source ? self[:source_role] : self[:target_role]
  end

  def other_icon
    @side == :source ? target_icon : source_icon
  end

  # Get class of other element (used by QueryNode to properly set resulting class).
  def other_vclass
    VirtualClass.find_by_kpath(@side == :source ? self[:target_kpath] : self[:source_kpath])
  end

  # set
  def other_id=(v)
    attributes_to_update[:errors] = {}
    if !v.kind_of?(Array) && v.to_i < 0
      # removing a link
      # TODO: support Array
      if link = other_links.select { |l| l[other_side] == -v }.first
        remove_link(link)
      else
        # ignore
      end
    else
      attributes_to_update[:id] = v.kind_of?(Array) ? v.uniq.compact.map {|v| v.to_i} : (v.blank? ? nil : v.to_i)
    end
  end

  # set
  def other_zip=(zip_values)
    # Translate ids and then set
    errors    = attributes_to_update[:errors]    = {}
    id_to_zip = attributes_to_update[:id_to_zip] = {}

    if zip_values.kind_of?(Array)
      attributes_to_update[:id] = []
      zip_values.each do |zip|
        if id = secure(Node) { Node.translate_pseudo_id(zip,  :id, @start) }
          # ok
          id_to_zip[id] = zip
          attributes_to_update[:id] << id
        else
          # error
          errors[zip] = _('could not be found')
        end
      end
    elsif zip_values.blank?
      # remove all
      attributes_to_update[:id] = nil
    else
      if id = secure(Node) { Node.translate_pseudo_id(zip_values, :id, @start) }
        if id < 0
          # removing a link
          # TODO: support Array
          if link = other_links.select { |l| l[other_side] == -id }.first
            remove_link(link)
          else
            # ignore
          end
        else
          id_to_zip[id] = zip_values
          attributes_to_update[:id] = id
        end
      else
        # error
        # do not try to add
        attributes_to_update[:id] = :ignore
        errors[zip_values] = _('could not be found')
      end
    end
  end

  def other_ids=(v)
    self.other_id = v
  end

  def other_zips=(v)
    self.other_zip = v
  end

  def remove_link(link)
    @links_to_delete ||= []
    @links_to_delete << link
  end

  LINK_ATTRIBUTES.each do |sym|
    define_method("other_#{sym}=") do |v|
      attributes_to_update[sym] = v.blank? ? nil : v
    end
  end

  def this_kpath
    @side == :source ? source_kpath : target_kpath
  end

  def other_kpath
    @side == :source ? target_kpath : source_kpath
  end

  # find the links from the current context (source or target)
  def other_links
    @other_links ||= Link.find(:all, :conditions => ["relation_id = ? AND #{link_side} = ?", self[:id], @start[:id]])
  end

  # link can be changed if user can write in old and new
  # 1. can remove old link
  # 2. can write in new target
  def attributes_to_update_valid?
    return true unless @attributes_to_update || @links_to_delete

    @link_errors  = {}
    @add_links    = []
    @del_links    = []
    @update_links = []

    if @links_to_delete
      # only removing links
      @del_links = @links_to_delete
      @attributes_to_update = {}
    else

      # check if we have an update/create
      unless @attributes_to_update.has_key?(:id) # set during other_id=
        # try to find current id/ids
        if @other_link
          @attributes_to_update[:id] = @other_link[other_side]
        elsif link_id = @start.link_id
          @other_link = Link.find(link_id)
          @attributes_to_update[:id] = @other_link[other_side]
        elsif unique?
          if other_id
            @attributes_to_update[:id] = other_id
          elsif @attributes_to_update.keys == [:id]
            # ignore (set icon_id = nil when already == nil)
          else
            @link_errors['update'] = _('missing target')
          end
        else
          # error: cannot set other attributes (status/comment) on multiple nodes
          @link_errors['update'] = _('cannot update multiple targets')
        end
      end

      if @attributes_to_update[:id].kind_of?(Array)
        if unique?
          # TODO: translate
          @link_errors['arity'] = "Cannot set multiple targets on #{as_unique? ? 'one' : 'many'}-to-one relation '#{this_role}'."
        elsif (@attributes_to_update.keys & LINK_ATTRIBUTES) != []
          keys = @attributes_to_update.keys
          keys.delete(:id)
          # TODO: translate
          @link_errors['arity'] = "Cannot set attributes #{keys.join(', ')} on multiple targets."
        end
      end

      return false if @link_errors != {}
      @link_errors = @attributes_to_update[:errors] || {}

      # 1. find what changed
      if @attributes_to_update[:id].kind_of?(Array)
        # ..-to-many
        # define all links

        # list of link ids set
        add_link_ids = @attributes_to_update[:id]

        # find all current links
        # TODO: this could be optimzed (avoid loading all links...)
        other_links.each do |link|
          obj_id = link[other_side]
          if add_link_ids.include?(obj_id) && (@attributes_to_update[:date].nil? || @attributes_to_update[:date] == link[:date])
            # ignore existing link
            add_link_ids.delete(obj_id)
          else
            # remove unused links / link to replace
            @del_links << link
          end
        end
        @add_links = add_link_ids.map {|obj_id| Hash[:id,obj_id] }
      elsif unique?
        # ..-to-one
        # define/update link
        if other_id == @attributes_to_update[:id]
          # same target: update
          @update_links << changed_link(other_link, @attributes_to_update)
        else
          # other target: replace
          @del_links = [other_link] if other_link
          @add_links << @attributes_to_update unless @attributes_to_update[:id].blank?
        end
      else
        # ..-to-many
        # add/update a link
        # TODO: optimize to avoid loading all links...
        if @attributes_to_update[:id].blank? && @attributes_to_update[:date]
          # delete
          @del_links = other_links.select {|l| @attributes_to_update[:date] == l[:date]}
        else
          links = other_links.select {|l| l[other_side] == @attributes_to_update[:id] && (@attributes_to_update[:date].nil? || @attributes_to_update[:date] == l[:date])}
          if links != []
            # update
            if (@attributes_to_update.keys & LINK_ATTRIBUTES) != []
              links.each do |link|
                if link[other_side] == @attributes_to_update[:id]
                  @update_links << changed_link(link, @attributes_to_update)
                end
              end
            end
          elsif @attributes_to_update[:id] == :ignore
            # bad id set, just used for error reporting
          else
            # add
            @add_links << @attributes_to_update
          end
        end
      end
    end

    id_to_zip = attributes_to_update[:id_to_zip] || {}

    # 2. can write in new target ? (and remove targets previous link)
    @add_links.each do |hash|
      # last_target is used by "linked_node" from Node to get hold of the last linked node
      if @last_target = find_target(hash[:id])
        # make sure we can overwrite previous link if as_unique
        if as_unique?
          if previous_link = Link.find(:first, :conditions => ["relation_id = ? AND #{other_side} = ?", self[:id], @last_target[:id]])
            @del_links << previous_link
          end
        end
      else
        if zip = id_to_zip[hash[:id]]
          key = zip
        elsif node = secure(Node) { Node.find_by_id(hash[:id]) }
          key = node.zip
        else
          key = 'id'
        end

        @link_errors[key] = _('invalid target')
      end
    end

    # 1. can remove old link ?
    @del_links.each do |link|
      unless find_node(link[other_side], unique?)
        if zip = id_to_zip[link[other_side]]
          key = zip
        elsif node = secure(Node) { Node.find_by_id(hash[:id]) }
          key = node.zip
        else
          key = 'id'
        end

        @link_errors[key] = _('cannot remove link')
      end
    end

    @update_links.compact!
    return @link_errors == {}
  end

  # Return updated link if changed or nil when nothing changed
  def changed_link(link, attrs)
    changed = false
    LINK_ATTRIBUTES.each do |sym|
      next unless attrs.has_key?(sym)
      if attrs[sym] != link[sym]
        changed = true
        link[sym] = attrs[sym]
      end
    end
    changed ? link : nil
  end

  def update_links!
    return unless @attributes_to_update
    @del_links.each    { |l| l.destroy }
    @update_links.each { |l| l.save }

    return if @add_links == []

    list = []
    @add_links.each do |hash|
      next if hash[:id].blank?
      list << ([self[:id], @start[:id], hash[:id]] + LINK_ATTRIBUTES.map{|sym| hash[sym]})
    end
    Zena::Db.insert_many('links', ['relation_id', link_side, other_side] + LINK_ATTRIBUTES, list)
    @attributes_to_update = nil
    @links_to_delete      = nil
    remove_instance_variable(:@records)     if defined?(@records)
    remove_instance_variable(:@record)      if defined?(@record)
    remove_instance_variable(:@other_links) if defined?(@other_links)
  end

  def unique?
    @side == :source ? target_unique : source_unique
  end

  def as_unique?
    @side == :source ? source_unique : target_unique
  end

  # def source_unique
  #   self[:source_unique] ? true : false
  # end
  #
  # def target_unique
  #   self[:target_unique] ? true : false
  # end

  def link_side
    @side == :source ? 'source_id' : 'target_id'
  end

  def other_side
    @side == :source ? 'target_id' : 'source_id'
  end

  private
    def relation_class
      @start.relation_base_class
    end

    def find_node(obj_id, unique)
      unique ? secure_drive(Node) { Node.find_by_id(obj_id) } : secure_write(Node) { Node.find_by_id(obj_id) }
    end

    def find_target(obj_id)
      if as_unique?
        secure_drive(relation_class) { relation_class.find(:first, :conditions=>['id = ? AND kpath LIKE ?', obj_id, "#{other_kpath}%"]) }
      else
        secure_write(relation_class) { relation_class.find(:first, :conditions=>['id = ? AND kpath LIKE ?', obj_id, "#{other_kpath}%"]) }
      end
    end

    def attributes_to_update
      @attributes_to_update ||= {}
    end
end
