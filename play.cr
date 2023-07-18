enum Color
  Red
  Green
  Blue
end

def paint(color : Color)
  case color
  when .red?
    puts "red"
  else
    # Unusual, but still can happen
    raise "unknown color: #{color}"
  end
end

paint :red