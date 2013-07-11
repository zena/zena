require 'delayed_job'

# Run during initialization
Delayed::Job.destroy_failed_jobs = false
silence_warnings do
  Delayed::Job.const_set("MAX_ATTEMPTS", 3)
  Delayed::Job.const_set("MAX_RUN_TIME", 5.minutes)
end

class Delayed::Job
  before_create :set_site_id
  private
    def set_site_id
      self[:site_id] = current_site[:id]
    end
end
