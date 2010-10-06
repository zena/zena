require 'bricks/pdf'

Bricks::PDF.engine = Bricks::CONFIG['pdf']['engine']

Zena::Use.module Bricks::PDF