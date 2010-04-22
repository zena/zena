class Column < ActiveRecord::Base
  include Property::StoredColumn
  belongs_to :role
  validates_presence_of :role
end
