class NoteController < ApplicationController
  helper MainHelper
  
  def day_list
    # used to display just the content of a single note (called by calender)
    @item          = secure(Item) { Item.find(params[:id]) }
    find           = params[:find] ? params[:find].to_sym : nil
    @note_date     = params[:date] ? Date.parse(params[:date]) : nil
    @selected_note = params[:selected] ? params[:selected].to_i : nil
    using          = params[:using] ? params[:using].gsub(/[^a-zA-Z_]/,'') : 'event_at'
    @notes         = notes(:from=>@item, :find=>find, :using=>using, :date=>@note_date, :order=>"#{using} ASC")
    render :partial=>'note/day_list'
  rescue ActiveRecord::RecordNotFound
    page_not_found
  end
  
  def create
     klass = params[:note][:klass] || 'Note'
     begin
        # FIXME: [SECURITY] is there a better way to find the class without using eval ?
       klass = eval "#{klass.gsub(/[^a-zA-Z]/,'').capitalize}"
       raise NameError unless klass.ancestors.include?(Note)
       params[:note].delete(:klass)
       parse_dates(params[:note])
       @note = secure(klass) { klass.create(params[:note]) }
       @item = @note.parent
     rescue NameError
       klass = params[:note][:klass]
       params[:note].delete(:klass)
       @note = secure(Note) { Note.new(params[:note]) }
       @note.errors.add('klass', 'invalid')
       @note.instance_eval {@klass=klass}
       def @note.klass; @klass; end
       @item = @note.parent
     end
   rescue ActiveRecord::RecordNotFound
     page_not_found
   end
end
