Tree = Struct.new(:name, :children) do
  def print_xml(depth = 0)
    if children
      puts "#{'  ' * depth}<#{name}>"
      children.each { |child| child.print_xml(depth + 1) }
      # puts "#{'  ' * depth}</#{name}>"
    else
      puts "#{'  ' * depth}#{name}"
    end
  end
end
