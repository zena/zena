module Bricks
  module Static
    ELEM = "([a-zA-Z_]+)"
    ELEM_REGEXP = %r{^#{ELEM}$}
    SECURE_PATH_REGEXP = %r{^[a-zA-Z_/]+$}
    STATIC_SKIN_REGEXP = %r{^#{ELEM}-#{ELEM}$}
    ZAFU_URL_REGEXP    = %r{^\$#{ELEM}-#{ELEM}/(.+)$}
    BRICK_NAME_REGEXP = %r{^#{RAILS_ROOT}/bricks/#{ELEM}/zena/skins$}

    module ControllerMethods
      def self.included(base)
        base.alias_method_chain :get_template_text, :static
        base.alias_method_chain :template_url_for_asset, :static
        base.alias_method_chain :get_best_template, :static
      end

      def get_template_text_with_static(path, section_id = nil)
        if path =~ ZAFU_URL_REGEXP
          brick_name, skin_name, path = $1, $2, $3
          text_from_static(brick_name, skin_name, path)
        elsif section_id.nil? && @static_brick_name && @static_skin_name
          text_from_static(@static_brick_name, @static_skin_name, path)
        else
          get_template_text_without_static(path, section_id)
        end
      end

      def template_url_for_asset_with_static(opts)
        # TODO
        template_url_for_asset_without_static(opts)
      end

      def get_best_template_with_static(kpaths, format, mode, skin)
        return get_best_template_with_static(kpaths, format, mode, skin) unless static = skin.z_static
        if idx_template = IdxTemplate.first(
           :conditions => ["tkpath IN (?) AND format = ? AND mode #{mode ? '=' : 'IS'} ? AND (skin_id = ? OR static = ?) AND site_id = ?",
              kpaths, format, mode, skin.id, static, skin.site_id],
            :order     => "length(tkpath) DESC, skin_id DESC"
          )
          if idx_template.path.nil?
            template = secure(Template) { Template.find(idx_template.node_id) }
            get_best_template_without_static(kpaths, format, mode, skin, template)
          elsif static =~ STATIC_SKIN_REGEXP
            @static_brick_name, @static_skin_name = $1, $2
            if idx_template.path =~ SECURE_PATH_REGEXP
              zafu_url = "$#{@static_brick_name}-#{@static_skin_name}/#{idx_template.path}"
              template = Template.new
              template.tkpath = idx_template.tkpath
              [zafu_url, template]
            end
          end
        end
      end

      # TODO
      # Asset resolution: route = /static/static-blog/img/style.css
      # ===> static brick ==> brick path
      # ===> blog/img/style.css ==> brick path/zena/skins/  blog/img/style.css
      # Cache in public directory
      # FIXME: clear_cache should erase /home/static

      private
        def text_from_static(brick_name, skin_name, path)
          if path =~ SECURE_PATH_REGEXP
            abs_path = File.join(
              RAILS_ROOT, 'bricks', brick_name,
              'zena', 'skins', skin_name, path + '.zafu')
            File.exist?(abs_path) ? File.read(abs_path) : nil
          end
        end
    end # ControllerMethods

    module SkinMethods
      def self.included(base)
        base.property do |p|
          p.string 'z_static'
        end

        base.validate :validate_z_static
      end

      private
        def validate_z_static
          if !(z_static.nil? || z_static =~ STATIC_SKIN_REGEXP)
            errors.add(:z_static, _('invalid'))
          end
          true
        end
    end # SkinMethods

    module SiteMethods
      def self.included(base)
        base.alias_method_chain :rebuild_index, :static
      end

      def rebuild_index_with_static(nodes = nil, page = nil, page_count = nil)    if !page
          Zena::SiteWorker.perform(self, :rebuild_static_index, nil)
        end
        rebuild_index_without_static(nodes, page, page_count)
      end

      def rebuild_static_index
        Zena::Db.execute "DELETE FROM idx_templates WHERE node_id IS NULL AND site_id = #{id}"
        Bricks.paths_for('zena/skins').each do |p|
          if p =~ BRICK_NAME_REGEXP
            brick_name = $1
            list = []
            Dir.foreach(p) do |skin_name|
              if skin_name =~ ELEM_REGEXP
                build_static_index(brick_name, skin_name, "#{p}/#{skin_name}")
              end
            end
          end
        end
      end

      private
        def build_static_index(brick_name, skin_name, path)
          # path = absolute path
          # 1. Find all templates
          Dir.foreach(path) do |elem|
            next if elem =~ /^\./
            elem_path = File.join(path, elem)
            if File.directory?(elem_path)
              build_static_index(brick_name, skin_name, elem_path)
            elsif elem =~ Template::MODE_FORMAT_FROM_TITLE
              # 2. Get klass, mode, format
              klass    = $1
              mode     = $4.blank? ? nil : $4
              format   = $6 || 'html'
              idx_path = elem_path[%r{^#{RAILS_ROOT}/bricks/#{brick_name}/zena/skins/#{skin_name}/(.+)\.zafu$}, 1]
              # 3. Get kpath
              if idx_path && vclass = VirtualClass[klass]
                tkpath = vclass.kpath

                # 4. insert idx_template entry (kpath, site_id, mode, format, path relative to bricks/brick/zena/skins/skin_name)
                IdxTemplate.create(
                  :tkpath  => tkpath,
                  :mode    => mode,
                  :format  => format,
                  :site_id => id,
                  :static  => "#{brick_name}-#{skin_name}",
                  :path    => idx_path
                )
              end
            end
          end
        end
    end # SiteMethods
  end # Static
end # Bricks