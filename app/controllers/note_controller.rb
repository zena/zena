class NoteController < ApplicationController

  def day_list
    # used to display just the content of a single note (called by calender)
    @node          = secure!(Node) { Node.find(params[:id]) }
    find           = params[:find] ? params[:find].to_sym : nil
    @note_date     = params[:date] ? Date.parse(params[:date]) : nil
    @selected_note = params[:selected] ? params[:selected].to_i : nil
    using          = params[:using] ? params[:using].gsub(/[^a-zA-Z_]/,'') : 'event_at'
    @notes         = notes(:from=>@node, :find=>find, :using=>using, :date=>@note_date)
    render :partial=>'note/day_list'
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end

  def create
    klass = params[:note][:klass] || 'Note'
    begin
      klass = Module::const_get(klass.capitalize.to_sym)
      raise NameError unless klass.ancestors.include?(Note)
      params[:note].delete(:klass)
      parse_dates(params[:note])
      @note = secure!(klass) { klass.create(params[:note]) }
      @node = @note.parent
    rescue NameError
      klass = params[:note][:klass]
      params[:note].delete(:klass)
      @note = secure!(Note) { Note.new(params[:note]) }
      @note.errors.add('klass', 'invalid')
      # this is to show the klass value in the form selection
      @note.instance_variable_set(:@klass, klass)
      def @note.klass; @klass; end
      @node = @note.parent
    end
  rescue ActiveRecord::RecordNotFound
    page_not_found
   end
end
