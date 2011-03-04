# This migration should be run in the 1.0 branch *AFTER* the migration
# to Zerox1Schema.
class Zerox1Data < ActiveRecord::Migration
  def self.up
    if connection.tables.include?('contact_contents')
      # Need to migrate data
      if $Zerox1SchemaRunning
        raise "=> Please restart migration: a restart is needed before running Zerox1Data."
      end
    else
      # Nothing to be done here
      puts "=>  No legacy data to migrate."
      return
    end
    puts "Plop!"
    # ============================================ contact_contents
    # migrate content to properties

    # ============================================ document_contents
    # migrate page ref to attachments
    # migrate content to properties

    # ============================================ versions
    # === dyn_attributes
    # migrate content to verisons properties
    # === idx_text_high => title
    # === idx_text_medium => summary
    # === idx_text_low => text

    # migrate to properties

    # ============================================ template_contents
    # migrate content to properties
    # rebuild index ==> should recreate idx_templates content

    # ============================================ nodes
    # 1. Set skin_id from skin name
    # 2. Set _id from current title


    # ============================================ roles
    # make properties from dyn_keys list ?

    # ============================================ site_attributes
    # migrate to properties
  end
end
