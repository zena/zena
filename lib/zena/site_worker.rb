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
        Thread.current[:visitor] = site.anon
      end

      if nodes = get_nodes
        # Register next one (if we are lucky and have many workers, we can parallelize work)
        Zena::SiteWorker.perform(site, action, page + 1)

        # do action on nodes
        site.send(action, nodes, page, page_count)
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
  end
end # Zena