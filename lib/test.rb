require_relative './grammar'
require_relative './tree'

def test(parser, grammar, input)
  puts '=' * 72
  puts ":: #{input}\n\n"

  parser.new(grammar).parse(input.chars).each.with_index do |tree, i|
    puts "--[ #{i + 1} ]#{'-' * 65}"
    tree.print_xml
    puts
  end
end
