class PageController < ApplicationController
  helper MainHelper
  
  def create
     klass = params[:page][:type] || 'Page'
     # FIXME: [SECURITY] is there a better way to find the class without using eval ?
     klass = eval "#{klass.gsub(/[^a-zA-Z]/,'').capitalize}"
     @page = secure(klass) { klass.create(params[:page]) }
   rescue ActiveRecord::RecordNotFound
     page_not_found
   end
end
