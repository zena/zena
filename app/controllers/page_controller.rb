class PageController < ApplicationController

  def create
    klass = params[:page][:klass] || 'Page'
    begin
      klass = Module::const_get(klass.capitalize.to_sym)
      raise NameError unless klass.ancestors.include?(Page)
      params[:page].delete(:klass)
      @page = secure(klass) { klass.create(params[:page]) }
      @node = @page.parent
    rescue NameError
      klass = params[:page][:klass]
      params[:page].delete(:klass)
      @page = secure(Page) { Page.new(params[:page]) }
      @page.errors.add('klass', 'invalid')
      # This is to show the klass in the form seizure
      @page.instance_variable_set(:@klass, klass)
      def @page.klass; @klass; end
      @node = @page.parent
    end
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
end
