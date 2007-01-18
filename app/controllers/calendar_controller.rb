class CalendarController < ApplicationController
  helper MainHelper
  
  # This action is used to change the calendar date with ajax
  def show
    get_options
    render :inline=>"<%= calendar(:from=>@node, :find=>@method, :size=>@size, :date=>@date) %>"
  rescue ActiveRecord::RecordNotFound
    render :nothing=>true
  end
  
  # This action opens the calendar, doing lots of RJS to hide tiny calendar and update with a notes list when necessary
  def open
    get_options
  rescue ActiveRecord::RecordNotFound
    render :nothing=>true
  end
  
  private
  
  def get_options
    @node   = secure(Node) { Node.find(params[:id]) }
    @method = params[:find] ? params[:find].to_sym : nil
    @date   = params[:date] ? Date.parse(params[:date]) : nil
    @size   = params[:size].to_sym
    if params[:day] && params[:row]
      row = params[:row].to_i
      day = params[:day].to_i
      if row == 1 && day > 20
        if date.mon == 1
          @note_date = Date.civil(@date.year-1, 12, day)
        else
          @note_date = Date.civil(@date.year, @date.mon - 1, day)
        end
      elsif row > 3 && day < 15
        if @date.mon == 12
          @note_date = Date.civil(@date.year+1, 1, day)
        else
          @note_date = Date.civil(@date.year, @date.mon + 1, day)
        end
      else
        @note_date = Date.civil(@date.year, @date.mon, day)
      end
      @notes = notes(:from=>@node, :find=>@method, :using=>:event_at, :date=>@note_date, :order=>'event_at ASC')
    end
  end
    
end
