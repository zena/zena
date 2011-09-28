require 'open4'
module Bricks
  module Helper
    def run(cd, *args)
      status = 0
      msg    = nil
      err    = nil
      cd ||= '.'
      Dir.chdir(cd) do
        status = Open4::popen4(*args) do |pid, stdin, stdout, stderr|
          msg = stdout.read
          err = stderr.read
        end
      end
      return status == 0, msg, err
    end
  end
end
