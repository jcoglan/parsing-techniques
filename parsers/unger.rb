require 'tree'

class Unger
  def initialize(grammar)
    @grammar = grammar.split_choices
  end

  def parse(tokens)
    @grammar.start_rules.flat_map { |rule| fit_to(rule, tokens) }
  end

  def fit_to(rule, tokens)
    partitions = partition(rule.rhs.entries, tokens)

    partitions.select! do |partition|
      partition.all? { |matcher, tokens| matcher_matches?(matcher, tokens) }
    end

    partitions.flat_map do |partition|
      combine_children(partition).map do |children|
        Tree.new(rule.lhs.name, children)
      end
    end
  end

  def matcher_matches?(matcher, tokens)
    case matcher
    when Terminal then [matcher.name] == tokens
    else true
    end
  end

  def partition(matchers, tokens)
    return [] if matchers.empty?
    return [[[matchers.first, tokens]]] if matchers.size == 1

    partition_range(matchers, tokens).flat_map do |n|
      first = [matchers.first, tokens.take(n)]
      rest  = partition(matchers.drop(1), tokens.drop(n))

      rest.map { |partition| [first] + partition }
    end
  end

  def partition_range(matchers, tokens)
    over = tokens.size - matchers.size
    over < 0 ? [] : (0 .. over).map(&:succ)
  end

  def combine_children(partition)
    return [[]] if partition.empty?

    matcher, tokens = partition.first

    if NonTerminal === matcher
      childs = @grammar.rules_for(matcher).flat_map { |rule| fit_to(rule, tokens) }
    else
      childs = [Tree.new(matcher.name)]
    end

    return [] if childs.empty?
    rest = combine_children(partition.drop(1))

    childs.flat_map do |child|
      rest.map { |nodes| [child] + nodes }
    end
  end
end

class UngerEmpty < Unger
  def fit_to(rule, tokens)
    @stack ||= Set.new

    key = [rule, tokens]
    return [] unless @stack.add?(key)

    super.tap { @stack.delete(key) }
  end

  def matcher_matches?(matcher, tokens)
    case matcher
    when Empty then tokens == []
    else super
    end
  end

  def partition_range(matchers, tokens)
    (0 .. tokens.size)
  end
end

if __FILE__ == $0
  require 'test'

  grammar = Grammar.parse <<-GMR
    Expr   → Expr + Term | Term
    Term   → Term × Factor | Factor
    Factor → ( Expr ) | i
  GMR

  test Unger, grammar, '(i+i)×i'

  grammar = Grammar.parse <<-GMR
    S → L S D | ε
    L → ε
    D → d
  GMR

  ['d', 'dd'].each do |input|
    test UngerEmpty, grammar, input
  end
end
