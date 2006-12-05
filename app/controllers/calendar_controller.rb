class CalendarController < ApplicationController
  layout false
  
  # This action is used to change the calendar date with ajax
  def show
    @source = secure(Item) { Item.find(params[:id]) }
    @find   = params[:find] ? params[:find].to_sym : nil
    @date   = params[:date] ? Date.parse(params[:date]) : nil
    @size = params[:size].to_sym
    render :inline=>"<%= calendar(:from=>@source, :find=>@find, :size=>@size, :date=>@date) %>"
  rescue ActiveRecord::RecordNotFound
    render :nothing=>true
  end
end
