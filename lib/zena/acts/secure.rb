module Zena
  module Acts
=begin rdoc
== Secure model
Read, write and publication access to an node is defined with four elements: one user and three groups.
link://rwp_groups.png

=== Definitions :
[inherit]  Defines how the groups propagate. If +inherit+ is set to '1', the node inherits rwp groups from it's reference. If
           +inherit+ is set to '0', the node has custom rwp groups. When set to '-1', the node is becomes private and all
           rwp groups are set to '0'.
[read]
    This means that the node can be seen.
[write]
    This means that new versions can be proposed for the node as well as new
    sub-pages, documents, events, etc. Basically can write = can add content. If a user has write access to
    a #Tag, this means he can add nodes to this #Tag (#Tag available as a category for other nodes).
[publish]
    This means that the content viewed by all can be altered by
    1. publishing new versions
    2. changing the node itself (name, groups, location, categories, etc)
    3. removing the node and/or sub-nodes
    4. people with this access can see nodes that are not published yet
[manage]
    This is for nodes that <em>have not yet been published</em> or for <em>private nodes</em>
    A. <em>private node</em>
    1. can 'publish' node (it is not really published as the node is private...)
    2. can 'unpublish' (make this node a 'not published yet')
    3. can change node itself (cannot change groups)
    4. can destroy
    B. <em>node not published yet</em> only :
    5. make an node private (sets all groups to 0) or revert node to default groups (same as parent or project) if node not published yet
    5. can see node (edition = personal redaction or latest version)

=== Who can do what (OBSOLTE: NEEDS UPDATE)
[read]
* super user
* owner
* members of +read_group+ if the node is published and the current date is greater or equal to the publication date
* members of +drive_group+ if +max_status+ >= prop

[write]
* super user
* owner
* members of +write_group+ if node is published and the current date is greater or equal to the publication date

[publish]
* super user
* members of +drive_group+ if +max_status+ >= prop
* owner if member of +drive_group+

[manage]
* owner if +max_status+ <= red
* owner if private

=== Misc

* A user can only set a group in which he/she belongs.
* Only people from the 'admin' group can change an node's owner.
* Setting all groups to _public_ transforms the node into a wiki.
* A user who belongs to the 'admin' group (id=2), automatically belongs to all other groups.

=== Usage

In the controller :
  require 'lib/acts_as_secure'
  class PagesController < ApplicationController
    before_filter :set_logged_in_user
    acts_as_secure

    def show
      @page = secure { Page.find(params[:id]) }
    end
    private
    def set_logged_in_user
      # .. get user
      session[:user] = @user[:id]
  end

#FIXME: correct doc.
In the model :
  require 'lib/acts_as_secure'
  class Page < ActiveRecord::Base
    acts_as_secure_node
  end

In the helpers (if you intend to use secure find there...)
  require 'lib/acts_as_secure'
  module ApplicationHelper
    include Zena::Acts::Secure
    # ...
  end
Just doing the above will filter all result according to the logged in user.
=end
    # ============================================= SECURE  ===============
    module Secure
      # protect access to site_id : should not be changed by users
      # def site_id=(i)
      #   raise Zena::AccessViolation, "#{self.class.to_s} '#{self.id}': tried to change 'site_id' to '#{i}'."
      # end

      # Set current visitor
      def visitor=(visitor)
        Thread.current[:visitor] = visitor
      end

      # Secure scope for read access
      def secure_scope(table_name)
        if visitor.is_su?
          "#{table_name}.site_id = #{visitor.site.id}"
        else
          # site_id AND...
          "#{table_name}.site_id = #{visitor.site.id} AND ("+
          # READER if published
          "(#{table_name}.rgroup_id IN (#{visitor.group_ids.join(',')}) AND #{table_name}.publish_from <= #{Zena::Db::NOW} ) OR " +
          # OR writer
          "#{table_name}.wgroup_id IN (#{visitor.group_ids.join(',')}))"
        end
      end

      def secure_write_scope
        scope = {:nodes => {:site_id => visitor.site[:id]}}
        scope[:nodes] = {:wgroup_id => visitor.group_ids} unless visitor.is_su?
        scope
      end

      # these methods are not actions that can be called from the web !!
      protected
        # secure find with scope (for read/write or publish access).
        def secure_with_scope(klass, node_find_scope)

          if ((klass.send(:scoped_methods)[0] || {})[:create] || {})[:visitor]
            # we are already in secure scope: this scope is the new 'exclusive' scope.
            last_scope = klass.send(:scoped_methods).shift
          end

          scope = {:create => { :visitor => visitor }}
          find = scope[:find] ||= {}
          if klass < Zena::Acts::SecureNode::InstanceMethods
            find[:conditions] = node_find_scope
          elsif klass <= ::Version
            ntbl = ::Node.table_name
            find[:joins] = :node
            find[:readonly] = false
            if node_find_scope =~ /publish_from/
              # read, we need to rewrite with node's table name
              find[:conditions] = secure_scope(ntbl)
            else
              find[:conditions] = node_find_scope
            end
          elsif klass.column_names.include?('site_id')
            find[:conditions] = {klass.table_name => {:site_id => visitor.site[:id]}}
          elsif klass <= ::Site
            find[:conditions] = {klass.table_name => {:id => visitor.site[:id]}}
          end

          # FIXME: 'with_scope' is protected now. Can we live with something cleaner like this ?
          # class AR::Base
          #   def self.secure_find(...)
          #      ...
          #   end
          # end
          #
          # or better:
          #  :conditions => '#{secure_scope}' (dynamically evaluated: single quotes)
          result = klass.send(:with_scope, scope) { yield }

          klass.send(:scoped_methods).unshift last_scope if last_scope

          secure_result(result)
        end

        # Secure for read/create.
        # [read]
        # * super user
        # * owner
        # * members of +read_group+ if the node is published and the current date is greater or equal to the publication date
        # * members of +drive_group+ if +max_status+ >= prop
        # The options hash is used internally by zena when maintaining parent to children inheritance and should not be used for other purpose if you do not want to break secure access.
        def secure(klass, opts={}, &block)
          if opts[:secure] == false
            yield
          else
            secure_with_scope(klass, secure_scope(klass.table_name), &block)
          end
        rescue ActiveRecord::RecordNotFound
          # Rails generated exceptions
          # TODO: monitor how often this happens and replace the finders concerned
          nil
        end

        def secure!(klass, opts={}, &block)
          unless res = secure(klass, opts={}, &block)
            raise ActiveRecord::RecordNotFound
          end
          res
        end

        # Secure scope for write access.
        # [write]
        # * super user
        # * owner
        # * members of +write_group+ if node is published and the current date is greater or equal to the publication date
        def secure_write(obj, &block)
          scope = {:nodes => {:site_id => visitor.site[:id]}}
          scope[:nodes] = {:wgroup_id => visitor.group_ids} unless visitor.is_su?
          secure_with_scope(obj, scope, &block)
        rescue ActiveRecord::RecordNotFound
          # Rails generated exceptions
          # TODO: monitor how often this happens and replace the finders concerned
          nil
        end

        # Find a node with write access. Raises an exception on failure.
        def secure_write!(obj, &block)
          unless res = secure_write(obj, &block)
            raise ActiveRecord::RecordNotFound
          end
          res
        end

        # Secure scope for publish or management access. This scope is a little looser then 'secure' (read access) concerning redactions
        # and 'not published yet' nodes. This is not a bug, such an access is needed to delete old nodes for example.
        # [publish]
        # * super user
        # * members of +drive_group+
        # * owner if member of +drive_group+ or private
        #
        # [manage]
        # * owner if +max_status+ <= red
        # * owner if private
        def secure_drive(obj, &block)
          # scope = if visitor.is_su? # super user
          #   "site_id = #{visitor.site.id}"
          # else
          #   "site_id = #{visitor.site.id} AND dgroup_id IN (#{visitor.group_ids.join(',')})"
          # end
          scope = { :nodes => {:site_id => visitor.site.id } }
          scope[:nodes][:dgroup_id] = visitor.group_ids unless visitor.is_su?
          secure_with_scope(obj, scope, &block)
        rescue ActiveRecord::RecordNotFound
          # Rails generated exceptions
          # TODO: monitor how often this happens and replace the finders concerned
          nil
        end

        # Find nodes with 'drive' authorization. Raises an exception on failure.
        def secure_drive!(obj, &block)
          if res = secure_drive(obj, &block)
            res
          else
            raise ActiveRecord::RecordNotFound
          end
        end

        def driveable?
          respond_to?(:dgroup_id)
        end

      # This module does two things:
      # 1. make the visitor visit each node
      # 2. fast version preload
      module SecureResult
        def secure_result(result)
          if result && result != []
            if result.kind_of?(Array)
              if result.first.kind_of?(::Node)
                id_map, ids = construct_id_map(result)
                ::Version.find(ids).each do |v|
                  if r = id_map[v.id]
                    r.version = v
                  end
                end
              end
            elsif result.kind_of?(::Node)
              visitor.visit(result)
            end
            result
          else
            nil
          end
        end

        # Take an array of records and return a 2-tuple: a hash of
        # version_id to record and a list of version ids. This method also
        # secures the node by calling visitor.visit(node).
        def construct_id_map(records)
          map   = {}
          v_ids = []
          records.each do |r|
            visitor.visit(r)
            v_id = r.version_id
            map[v_id] = r
            v_ids << v_id
          end
          [map, v_ids]
        end
      end # SecureResult

      include SecureResult
    end # Secure
  end # Acts
  # This exception handles all flagrant access violations or tentatives (like suppression of _su_ user)
  class AccessViolation < StandardError
  end

  # This exception occurs when a visitor is needed but none was provided.
  class RecordNotSecured < StandardError
  end

  # This exception occurs when corrupt data in encountered (infinit loops, etc)
  class InvalidRecord < StandardError
  end
end # Zena

### ============== GLOBAL METHODS ACCESSIBLE TO ALL OBJECTS ============== ######

# Return the current site. Raise an error if the visitor is not set.
def current_site
  visitor.site
end

# Return the current visitor. Raise an error if the visitor is not set.
# For controllers, this method must be redefined in Application
def visitor
  Thread.current[:visitor] || Zena::RecordNotSecured.new("Visitor not set, record not secured.")
end

if defined?(IRB)
  puts "IRB console: including Zena::Acts::Secure in main"
  class << self
    include Zena::Acts::Secure

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
        puts "Logged #{visitor.fullname.inspect} (#{visitor.login}) in #{visitor.site.host}"
      else
        raise ActiveRecord::RecordNotFound
      end
    rescue ActiveRecord::RecordNotFound
      puts "Could not login with user name: #{name}"
    end

    def nodes(node_zip)
      secure(Node) { Node.find_by_zip(node_zip) }
    end
  end
end
