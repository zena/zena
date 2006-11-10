class LanguageController < ApplicationController
end
=begin


# menu to change language
def lang_menu
  @languages = Translation.find_by_sql("SELECT DISTINCT lang FROM translations ORDER BY lang").map {|t| [t.lang, t.lang] }
  render(:layout=>false)
end

=end