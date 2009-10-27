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
      # FIXME: when moving a template or a page that is a parent of a template: we must sync skin_name after spread_project_and_section.
      Skin.connection.execute "UPDATE template_contents SET skin_name = #{Zena::Db.quote(name)} WHERE template_contents.node_id IN (SELECT id FROM nodes WHERE nodes.section_id = #{Zena::Db.quote(self[:id])}) AND template_contents.site_id = #{Zena::Db.quote(self[:site_id])}"
    end
end