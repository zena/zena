class CalendarController < ApplicationController
  layout false
  
  # This action is used to change the calendar date with ajax
  def show
    @format = params[:format].to_sym
    @source = secure(Item) { Item.find(params[:id]) }
    @date   = params[:date] ? Date.parse(params[:date]) : nil
    render :inline=>"<%= calendar(@format, @source, @date) %>"
  rescue ActiveRecord::RecordNotFound
    render :nothing=>true
  end
  
  def list
    # used to display just the content of a single note (called by calender)
    @format   = params[:format].to_sym
    @source   = secure(Item) { Item.find(params[:id]) }
    @date     = params[:date] ? Date.parse(params[:date]) : nil
    @selected = params[:selected]
    render :inline=>"<%= notes_list(@format, @source, @date, :selected=>@selected) %>"
  rescue ActiveRecord::RecordNotFound
    render :nothing=>true
  end
end
