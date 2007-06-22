class CalendarController < ApplicationController
  before_filter :get_options
  # This action is used to change the calendar date with ajax
  def show
    render :inline=>"<%= calendar(:node => @node, :date => @date, :options => @options, :template_url => params[:template_url]) %>"
  end
  
  # This action opens the calendar, doing lots of RJS to hide tiny calendar and update with a notes list when necessary
  def open
  end
  
  def notes
    find_notes
    render :partial=>'note/day_list'
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
  private
  
    def get_options
      @node    = secure(Node) { Node.find_by_zip(params[:id]) }
      @options = eval_parameters_from_template_url
      @date    = Date.parse(params[:date])
      @options[:using] ||= 'log_at'
      @options[:size ]   = params[:size] || @options[:size]
    
      if params[:day] && params[:row]
        row = params[:row].to_i
        day = params[:day].to_i
        if row == 1 && day > 20
          if @date.mon == 1
            @date = Date.civil(@date.year-1, 12, day)
          else
            @date = Date.civil(@date.year, @date.mon - 1, day)
          end
        elsif row > 3 && day < 15
          if @date.mon == 12
            @date = Date.civil(@date.year+1, 1, day)
          else
            @date = Date.civil(@date.year, @date.mon + 1, day)
          end
        else
          @date = Date.civil(@date.year, @date.mon, day)
        end
      
      end
      # FIXME: convert date to utc...
      find_notes
    end
    
    def find_notes
      @notes = @node.relation(@options[:find], @options.merge(
          :conditions => ["date(#{@options[:using]}) = ?", @date],
          :order => "#{@options[:using]} ASC")) || []
    end
    
end
