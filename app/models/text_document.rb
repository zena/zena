=begin rdoc
Any document that can be edited as text (html file, script, source code) is a text document. The file content is not stored in an external file. It is kept in the version text. This means that the content of such a document can be edited by editing the version's text.

=== Version

The version class used by text documents is the TextDocumentVersion.

=== Content

Content (file data) is stored in the TextDocumentVersion. The content class (TextDocumentContent) is responsible for faking the exitence of a real file.
=end
class TextDocument < Document

  # Class Methods
  class << self
    # Return true if a new text document can be created with the content_type. Used by the superclass Document to choose the corret subclass when creating a new object.
    def accept_content_type?(content_type)
      (content_type =~ /^(text)/ && Zena::TYPE_TO_EXT[content_type.chomp] != ['rtf']) || (content_type =~ /x-javascript/)
    end

    def version_class
      TextDocumentVersion
    end
  end # Class Methods


  def can_parse_assets?
    return ['text/css'].include?(content_type)
  end

  # Parse text content and replace all reference to relative urls ('img/footer.png') by their zen_path ('/en/image34.png')
  def parse_assets(text, helper, key)
    if key == 'text' && prop['content_type'] == 'text/css'
      res = text.dup
      # use skin as root
      skin = section

      # not in a Skin. Cannot replace assets in CSS.
      # error
      unless skin.kind_of?(Skin)
        errors.add('base', 'Cannot parse assets if not in a Skin.')
        return text
      end

      current_dir = parent.fullpath

      res.gsub!(/url\(\s*(.*?)\s*\)/) do
        match, src = $&, $1
        if src =~ /('|")(.*?)\1/
          quote, src = $1, $2
        else
          quote = "'"
        end
        if src[0..6] == 'http://'
          match
        elsif src =~ %r{/\w\w/.*?(\d+)(_\w+|)\.\w+(\?\d+|)}
          # already parsed
          zip, mode, stamp = $1, $2, $3
          if src_node = secure(Node) { Node.find_by_zip(zip) }
            if mode.blank?
              # no cachestamp, we need it
              "url(#{quote}#{helper.send(:data_path, src_node)}#{quote})"
            else
              "url(#{quote}#{helper.send(:data_path, src_node, :mode => mode[1..-1])}#{quote})"
            end
          else
            # ok
            "url(#{quote}#{src}#{quote})"
          end
        else
          if new_src = helper.send(:template_url_for_asset, :src => src, :current_dir=>current_dir, :parse_assets => true)
            "url(#{quote}#{new_src}#{quote})"
          elsif !(src =~ /\.\./) && File.exist?(File.join(SITES_ROOT, current_site.public_path, src))
            "url(#{quote}#{src}?#{File.mtime(File.join(SITES_ROOT, current_site.public_path, src)).to_i}#{quote})"
          else
            errors.add('asset', '{{asset}} not found', :asset => src.inspect)
            "url(#{quote}#{src}#{quote})"
          end
        end
      end
    else
      # unknown type
      super
    end
    res
  end

  def file=(file)
    @new_file = super
    self.text = @new_file.read
  end

  def file(format=nil)
    @loaded_file ||= @new_file || StringIO.new(text)
  end

  def filename
    "#{title}.#{ext}"
  end

  # Return document file size (= version's text size).
  def size(format=nil)
    (text || '').size
  end

  # Parse text and replace absolute urls ('/en/image30.jpg') by their relative value in the current skin ('img/bird.jpg')
  def unparse_assets(text, helper, key)
    if key == 'text' && prop['content_type'] == 'text/css'
      res = text.dup
      # use parent as relative root
      current_dir = parent.fullpath

      res.gsub!(/url\(('|")(.*?)\1\)/) do
        if $2[0..6] == 'http://'
          $&
        else
          quote, url   = $1, $2
          if url =~ /\A\/\w\w\/.*?(\d+)(_\w+|)\./
            zip, mode = $1, $2
            if asset = secure(Node) { Node.find_by_zip(zip) }
              if asset.fullpath =~ /\A#{current_dir}\/(.+)/
                "url(#{quote}#{$1}#{mode}.#{asset.prop['ext']}#{quote})"
              else
                "url(#{quote}/#{asset.fullpath}#{mode}.#{asset.prop['ext']}#{quote})"
              end
            else
              errors.add('asset', '{{zip}} not found', :zip => zip)
              "url(#{quote}#{url}#{quote})"
            end
          elsif File.exist?(File.join(SITES_ROOT, current_site.public_path, url.sub(/\?\d+\Z/,'')))
            "url(#{quote}#{url.sub(/\?\d+\Z/,'')}#{quote})"
          else
            # bad format
            errors.add('base', "cannot unparse asset url #{url.inspect}")
            "url(#{quote}#{url}#{quote})"
          end
        end
      end
      res
    else
      super
    end
  end

  # List of keys to export in a zml file. "text" is ignored since it's exported in a separate file.
  def export_keys
    h = super
    h[:zazen].delete('text')
    h
  end

  # List of keys which need transformations
  def parse_keys
    (super + (content_type == 'text/css' ? ['text'] : [])).uniq
  end

  # Return the code language used for syntax highlighting.
  def content_lang
    ctype = prop['content_type']
    if ctype =~ /^text\/(.*)/
      case $1
      when 'x-ruby-script'
        'ruby'
      when 'html', 'zafu'
        'zafu'
      else
        $1
      end
    else
      nil
    end
  end

  private

    # Overwrite superclass (DocumentContent) behavior
    def valid_file
      return true
    end

    def set_defaults
      super
      self.content_type = 'text/plain' if content_type.blank?
      self.ext          = 'txt'        if ext.blank?
    end

    # This is triggered after create (after the image has been saved but
    # before the properties are saved with the version).
    def save_version_after_create
      parse_assets_before_save
      super
    end

    def parse_assets_before_save
      if can_parse_assets? && prop.text_changed?
        helper = AssetHelper.new
        helper.visitor = visitor
        self.text = parse_assets(self.text, helper, 'text')
      end
    end
end
