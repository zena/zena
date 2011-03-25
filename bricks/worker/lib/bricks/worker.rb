module Bricks
  module Worker
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
        jobs = Bricks::Worker::Job.find(:all,
          # FIXME: find a way to add site_id to delayed_jobs...
          #:conditions => ['site_id = ?', current_site.id],
          :order => 'run_at ASC'
        )
        jobs.empty? ? nil : jobs
      end
    end # ViewMethods
  end # Worker
end

# Make sure the class is loaded before first YAML.load
Zena::SiteWorker