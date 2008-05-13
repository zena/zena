class DocumentsKpathChange < ActiveRecord::Migration
  def self.up
    # this could break on paths like 'NNPD' (Note <- News <- Post <- Dobidou). But it's very unlikely to be
    # widespread and we haven't released anything yet (pre-alpha).
    execute "UPDATE nodes SET kpath = REPLACE(kpath, 'NPD', 'ND')"
    execute "UPDATE template_contents SET tkpath = REPLACE(tkpath, 'NPD', 'ND')"
    execute "UPDATE relations SET target_kpath = REPLACE(target_kpath, 'NPD', 'ND')"
    execute "UPDATE relations SET source_kpath = REPLACE(source_kpath, 'NPD', 'ND')"
  end

  def self.down
    execute "UPDATE nodes SET kpath = REPLACE(kpath, 'ND', 'NPD')"
    execute "UPDATE template_contents SET tkpath = REPLACE(tkpath, 'ND', 'NPD')"
    execute "UPDATE relations SET target_kpath = REPLACE(target_kpath, 'ND', 'NPD')"
    execute "UPDATE relations SET source_kpath = REPLACE(source_kpath, 'ND', 'NPD')"
  end
end
