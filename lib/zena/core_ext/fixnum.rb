class Fixnum
  # Convert a number of seconds to a string representation of a duration as '3 days', '2 hours', '1 day 2 hours 5 minutes 3 seconds'. See String::to_duration for the reverse conversion. A month is 30 days.
  def as_duration
    rest    = self
    years   = self / 31536000
    months  = (rest -= years  * 31536000) / 2592000
    days    = (rest -= months * 2592000)  / 86400
    hours   = (rest -= days   * 86400)    / 3600
    minutes = (rest -= hours  * 3600)     / 60
    seconds =  rest - minutes * 60
    res = []
    res << "#{years  } year#{  years   == 1 ? '' : 's'}" if years   != 0
    res << "#{months } month#{ months  == 1 ? '' : 's'}" if months  != 0
    res << "#{days   } day#{   days    == 1 ? '' : 's'}" if days    != 0
    res << "#{hours  } hour#{  hours   == 1 ? '' : 's'}" if hours   != 0
    res << "#{minutes} minute#{minutes == 1 ? '' : 's'}" if minutes != 0
    res << "#{seconds} second#{seconds == 1 ? '' : 's'}" if seconds != 0
    res == [] ? '0' : res.join(' ')
  end
  
  def fmt(format)
    # TODO: Better strftime with thousand separator
  end
end