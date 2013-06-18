module Zena
  class SiteWorker < Struct.new(:site_id, :action, :page)
    include Zena::Acts::Secure

    # Execute operations on 250 nodes at a time
    CHUNK_SIZE = 250

    def self.perform(site, action, page = 1)
      action = new(site.id, action, page)

      if Bricks::CONFIG['worker']
        Delayed::Job.enqueue action
      else
        # No worker: do it now
        action.perform(site)
      end
    end

    def perform(site = nil)
      if site.nil?
        site ||= Site.find(site_id)
        setup_visitor(site.any_admin, site)
      end

      if page.nil?
        site.send(action)
      else
        if nodes = get_nodes
          # Register next one (if we are lucky and have many workers, we can parallelize work)
          Zena::SiteWorker.perform(site, action, page + 1)

          # do action on nodes
          begin
            site.send(action, nodes, page, page_count)
          rescue => err
            # If we let the action fail, it will rerun and we will recreate an action for page + 1 !
            Site.logger.warn "[JOB] Failed: '#{action}'"
            Site.logger.warn err.message
          end
          
        end
      end
    end

    def get_nodes
      nodes = Node.find(:all,
        :conditions => ['site_id = ?', site_id],
        :limit  => CHUNK_SIZE,
        :offset => (page - 1) * CHUNK_SIZE,
        :order => 'id DESC'
      )
      secure_result(nodes)
    end

    def page_count
      (Node.count(:conditions => ['site_id = ?', site_id]) / CHUNK_SIZE) + 1
    end

    # Return a textual description of the operation.
    def info
      if site_id == current_site.site_id
        "#{action}, #{_('page')} #{page}/#{page_count}"
      else
        # Do not show jobs from other sites
        "-"
      end
    end
  end
end # Zena