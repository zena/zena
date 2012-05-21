class Float
  # Format a float with thousand separator and decimal positions.
  def fmt(pos=2,sep="'")
    i = self.to_i.to_s.reverse
    i.gsub(/(\d\d\d)(?=\d)(?!\d*\.)/,'\1'+sep).reverse
  end
end