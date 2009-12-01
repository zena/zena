class PingsController < ApplicationController
  def show
    whoami = {
      'visitor' =>  "#{visitor.first_name} #{visitor.name}",
      'site' => current_site.name,
      'format' => request.format.to_s
      }
    whoami_xml = Builder::XmlMarkup.new.ping do |p|
      p.visitor(whoami['visitor'])
      p.site(whoami['site'])
      p.format(whoami['format'])
    end
    respond_to do |wants|
      wants.html { render :text => whoami.inspect  }
      wants.xml { render :xml => whoami_xml }
    end
  end

end
