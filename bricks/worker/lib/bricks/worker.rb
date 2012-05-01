module Bricks
  module Worker
    # This is only used to display jobs. Job creation is done in Delayed::Job.
    class Job < ActiveRecord::Base
      include RubyLess
      set_table_name :delayed_jobs

      safe_method  :run_at => Time, :created_at => Time, :info   => String
      # can be nil
      safe_context :locked_at => Time, :locked_by => String

      def info
        obj = YAML.load(self[:handler])
        if obj.respond_to?(:info)
          obj.info
        else
          obj.inspect
        end
      end
    end # Job

    module ViewMethods
      include RubyLess

      safe_context :delayed_jobs => [Job]

      def delayed_jobs
        jobs = current_site.jobs
        jobs.empty? ? nil : jobs
      end
    end # ViewMethods
    
    module SiteMethods
      def jobs
        Bricks::Worker::Job.all(
          :conditions => ['site_id = ?', self.id],
          :order => 'run_at ASC'
        )
      end
    end
  end # Worker
end

# Make sure the class is loaded before first YAML.load
Zena::SiteWorker