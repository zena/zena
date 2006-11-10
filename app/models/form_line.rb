class FormLine < ActiveRecord::Base
  belongs_to :seizure, :class_name=>'form_seizure', :foreign_key=>'seizure_id'
end
