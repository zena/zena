=begin rdoc
== Index Page
+ZENA_ENV[:index_id]+ refers to a special project. This project is the root of all other pages or logs. It is used
to set default groups for new projects, to store 'global' events and pages.
=end
class Page < Item
  class << self
    def select_classes
      list = subclasses.inject([]) do |list, k|
        unless Document == k || k.ancestors.include?(Document)
          list << [k.to_s, k.to_s]
        end
        list
      end.sort
      list.unshift ['Page', 'Page']
    end
  end
  
  def klass
    self.class.to_s
  end
end