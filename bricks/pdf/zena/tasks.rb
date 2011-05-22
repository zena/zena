namespace :pdf do
  desc "Install binary for xhtml2pdf library"
  task :xhtml2pdf => :environment do
    install = Bricks::Pdf::Install
    install.from_url "http://pypi.python.org/packages/source/p/pisa/pisa-3.0.33.tar.gz", :md5 => 'e2040b12211303d065bc4ae2470d2700'

    install.from_url "http://www.reportlab.com/ftp/reportlab-2.5.tar.gz"

    install.from_url 'http://html5lib.googlecode.com/files/html5lib-0.11.1.zip', :sha1=>'157506319e40f5d973c128e5e2b826cd1bee471e'

    install.from_url 'http://effbot.org/downloads/Imaging-1.1.7.tar.gz'

    install.from_url 'http://pybrary.net/pyPdf/pyPdf-1.12.tar.gz'

    puts "\n==========================================\nBricks::Pdf dependencies installation done"
  end
end