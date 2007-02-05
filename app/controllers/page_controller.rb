class PageController < ApplicationController

  def create
    klass = params[:page][:klass] || 'Page'
    # FIXME: [SECURITY] is there a better way to find the class without using eval ?
    begin
      klass = eval "#{klass.gsub(/[^a-zA-Z]/,'').capitalize}"
      raise NameError unless klass.ancestors.include?(Page)
      params[:page].delete(:klass)
      @page = secure(klass) { klass.create(params[:page]) }
      @node = @page.parent
    rescue NameError
      klass = params[:page][:klass]
      params[:page].delete(:klass)
      @page = secure(Page) { Page.new(params[:page]) }
      @page.errors.add('klass', 'invalid')
      @page.instance_eval {@klass=klass}
      def @page.klass; @klass; end
      @node = @page.parent
    end
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
end
