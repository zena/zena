=begin rdoc
Definitions:

* master template: used to render a node. It is used depending on it's 'klass' filter.
* helper template: included into another template.

Render ---> Master template --include--> helper template --include--> ...

For master templates, the name is build from the different filters (klass, mode, format):

Klass-mode-format. Examples: Node-index, Node--xml, Project-info. Note how the format is omitted when it is 'html'.

Other templates have a name built from the given name, just like any other node.

=end
class Template < TextDocument
  validate :valid_section
  after_save :update_content

  class << self
    def accept_content_type?(content_type)
      content_type =~ /text\/(html|zafu)/
    end

    def version_class
      TemplateVersion
    end
  end

  def filter_attributes(attributes)
    content    = version.content
    version_attributes = attributes['version_attributes'] ||= {}
    new_name   = attributes['name'] || (new_record? ? (attributes['version_attributes'] || {})['title'] : nil) # only set name from version title on creation
    content_attributes = version_attributes ||= {}
    if new_name =~ /^([A-Z][a-zA-Z]+?)(-(([a-zA-Z_\+]*)(-([a-zA-Z_]+)|))|)(\.|\Z)/
      content_attributes['klass' ] ||= $1
      content_attributes['mode'  ] ||= $4
      content_attributes['format'] ||= ($6 || 'html')
    elsif new_name && !content_attributes['klass']
      # name set but it is not a master template name
      content_attributes['klass'] = nil
    elsif !new_name
      # force node update with new name
      attributes['name'] = name_from_content(:format => content_attributes['format'], :mode => content_attributes['mode'], :klass => content_attributes['klass']) if content[:klass] && !new_record?
    end
    super(attributes)
  end

  private

    # Overwrite document behaviour.
    def document_before_validation
      content = version.content

      content.mode = content.mode.url_name if content.mode

      if content.klass
        # update name
        content.format = 'html' if content.format.blank?
        self[:name] = name_from_content(:format => content.format, :mode => content.mode, :klass => content.klass)

        if version.text.blank? && content.format == 'html' && content.mode != '+edit'
          # set a default text

          if content.klass == 'Node'
            version.text = <<END_TXT
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" do='void' lang="en" set_lang='[v_lang]' xml:lang='en'>
<head do='void' name='head'>
  <title do='title_for_layout' do='show' attr='v_title' name='page_title'>page title</title>
  <!-- link href='favicon.png' rel='shortcut icon' type='image/png' / -->
  <meta http-equiv="Content-type" content="text/html; charset=utf-8" />
  <r:void name='stylesheets'>
    <r:stylesheets list='reset,zena,code'/>
    <link href="style.css" rel="Stylesheet" type="text/css"/>
  </r:void>

  <r:javascripts list='prototype,effects,zena'/>
  <r:uses_datebox/>
</head>
<body>
</body>
</html>
END_TXT
          else
            version.text = "<r:include template='Node'/>\n"
          end
        end
      end
    end

    def valid_section
      @need_skin_name_update = !new_record? && section_id_changed?
      errors.add('parent_id', 'Invalid parent (section is not a Skin)') unless section.kind_of?(Skin)
    end

    def name_from_content(opts={})
      opts[:format]  ||= version.content.format
      opts[:mode  ]  ||= version.content.mode
      opts[:klass ]  ||= version.content.klass
      format = opts[:format] == 'html' ? '' : "-#{opts[:format]}"
      mode   = (!opts[:mode].blank? || format != '') ? "-#{opts[:mode]}" : ''
      "#{opts[:klass]}#{mode}#{format}"
    end

    def update_content
      if @need_skin_name_update
        Template.connection.execute "UPDATE template_contents SET skin_name = #{Template.connection.quote(section[:name])} WHERE node_id = #{Template.connection.quote(self[:id])}"
        @need_skin_name_update = nil
      end
    end

end
