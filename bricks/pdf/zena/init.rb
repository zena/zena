require 'bricks/pdf'

Bricks::Pdf.engine = Bricks::CONFIG['pdf']['engine']

Zena.use Bricks::Pdf