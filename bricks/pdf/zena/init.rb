require 'bricks/pdf'

Bricks::Pdf.engine = Bricks::CONFIG['pdf']['engine']

Zena::Use.module Bricks::Pdf