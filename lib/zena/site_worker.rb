module Zena
  class SiteWorker < Struct.new(:site_id, :action, :page)
    include Zena::Acts::Secure

    # Execute operations on 50 nodes at a time
    CHUNK_SIZE = 50

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
        Zena::SiteWorker.perform(site, :rebuild_index, page + 1)

        # do action on nodes
        site.send(action, nodes)
      end
    end

    def get_nodes
      nodes = Node.find(:all,
        :conditions => ['site_id = ?', site_id],
        :limit  => CHUNK_SIZE,
        :offset => (page - 1) * CHUNK_SIZE,
        :order => 'id ASC'
      )
      secure_result(nodes)
    end
  end
end # Zena