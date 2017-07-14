require 'grammar'

class CYK
  def initialize(grammar)
    @grammar = grammar.to_cnf
  end

  def parse(tokens)
    Parse.new(@grammar, tokens).run
  end

  class Parse
    def initialize(grammar, tokens)
      @grammar = grammar
      @tokens  = tokens
    end

    def run
      @table = Table.build(@grammar, @tokens)
      derivations(@grammar.start_symbol, 1, @tokens.size)
    end

    def recognised?
      @table.lookup(1, @tokens.size).member?(@grammar.start_symbol)
    end

    def derivations(symbol, i, l)
      set = @table.lookup(i, l)
      return [] unless set.member?(symbol)

      if l == 1
        return [Tree.new(symbol.name, [Tree.new(@tokens[i - 1])])]
      end

      @grammar.rules_for(symbol).find_all(&:sequence?).flat_map do |rule|
        left, right = rule.rhs.items

        (1 ... l).flat_map do |k|
          a = derivations(left, i, k)
          b = derivations(right, i + k, l - k)

          Algo.product(a, b) { |x, y| Tree.new(symbol.name, [x, y]) }
        end
      end
    end
  end

  class Table
    def self.build(grammar, tokens)
      new(grammar, tokens).tap(&:build)
    end

    def initialize(grammar, tokens)
      @grammar = grammar
      @tokens  = tokens
    end

    def print
      @entries.each_with_index do |row, k|
        puts "--- R(i,#{k+1}) ------"
        row.each_with_index do |set, i|
          puts "        R(#{i+1},#{k+1}) = #{set.inspect}"
        end
      end
    end

    def lookup(i, k)
      @entries[k - 1][i - 1]
    end

    def build
      @entries = [build_first_row]

      n = @tokens.size

      (2 .. n).each do |k|
        @entries[k - 1] = (1 .. n + 1 - k).map { |i| build_table_entry(i, k) }
      end
    end

    def build_first_row
      @tokens.map do |token|
        rules = @grammar.rules.find_all { |rule| rule.match? token }
        Set.new(rules.map(&:lhs))
      end
    end

    def build_table_entry(i, l)
      pairs = (1 ... l).map { |k| [i, k, i + k, l - k] }

      rules = pairs.flat_map do |i1, k1, i2, k2|
        left   = lookup(i1, k1)
        right  = lookup(i2, k2)
        combos = Algo.product(left, right) { |a, b| [a, b ] }

        rules = combos.flat_map do |x, y|
          find_rules { |rule| rule.is? Sequence.new([x, y]) }
        end
        rules.map(&:lhs)
      end

      Set.new(rules)
    end

    def find_rules(&block)
      @grammar.rules.find_all(&block)
    end
  end
end

if __FILE__ == $0
  require 'test'

  grammar = Grammar.parse <<-GMR
    Number   -> Integer | Real
    Integer  -> Digit | Integer Digit
    Real     -> Integer Fraction Scale
    Fraction -> . Integer
    Scale    -> e Sign Integer | Empty
    Digit    -> 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9
    Sign     -> + | -
    Empty    -> ε
  GMR

  p grammar.to_cnf.join_choices

  test CYK, grammar, '32.5e+1'
end
