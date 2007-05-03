class Section < Page
  def get_section_id
    self[:id]
  end
end