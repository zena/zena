require 'fileutils'
class ChangeFileStorage < ActiveRecord::Migration
  def self.up
    directories_to_remove = []
    Site.find(:all).each do |site|
      data_path = "#{SITES_ROOT}#{site.data_path}"
      if File.exist?(data_path)
        FileUtils::mv(data_path, "#{data_path}_old")
        old_data_path = "#{data_path}_old"
        directories_to_remove << "#{old_data_path}"
      end
      
      DocumentContent.find(:all, :conditions => "site_id = #{site[:id]}").each do |doc|
        current_file = "#{old_data_path}/#{doc.ext}/#{doc.version_id}/#{doc.name}.#{doc.ext}"
        new_file     = doc.filepath
        if File.exist?(current_file)
          FileUtils::mkpath(File.dirname(new_file)) unless File.exist?(File.dirname(new_file))
          FileUtils::cp(current_file, new_file)
        else
          puts "Problem with document_content #{doc[:id]}, file #{current_file.inspect} does not exist."
        end
      end
      
      site.clear_cache(false)
    end
    
    puts "--------- migration done ----------"
    puts "if the change file storage went like a breeze,
you should run the following command:
rm -rf #{directories_to_remove.map{|s| s.inspect}.join(' ')}"
    puts "WARNING: you should fix the permissions on the new data folders with a command like:
chown -R www-data:www-data #{SITES_ROOT.inspect}"
  end

  def self.down
    puts "No one should ever need to migrate the ChangeFileStorage back. So it was not implemented because I am lazy..."
  end
end
