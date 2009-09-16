# A skin is a master template containing all sub templates and css to render a full site or sectioon
# of a site.
class Skin < Section
  before_save :set_need_skin_name_update
  after_save  :update_skin_name

  private

    def set_need_skin_name_update
      @need_skin_name_update = !new_record? && name_changed?
      true # save can continue
    end

    def update_skin_name
      return unless @need_skin_name_update
      # FIXME: escape correctly against sql injection
      # FIXME: when moving a template or a page that is a parent of a template: we must sync skin_name after spread_project_and_section.
      Skin.connection.execute "UPDATE nodes,template_contents SET template_contents.skin_name = #{Skin.connection.quote(name)} WHERE nodes.id = template_contents.node_id AND nodes.section_id = #{self[:id]} AND template_contents.site_id = '#{self[:site_id]}'"
    end
end