
# Dummy model for zip counter...
# TODO: there might be a better way to avoid errors when loading fixtures "zips.yml"
class ZipClass < ActiveRecord::Base
  set_table_name :zips
end

