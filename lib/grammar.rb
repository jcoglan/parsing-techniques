require_relative './algo'
require_relative './tree'

Grammar = Struct.new(:rules) do
  def self.parse(source)
    Grammar::Parser.parse(source, :actions => Grammar::Builder.new)
  end

  Rule = Struct.new(:lhs, :rhs) do
    def inspect(width = nil)
      padding = width ? width - lhs.name.size : 0
      "#{lhs.name}#{' ' * padding} → #{rhs.inspect}"
    end

    def nonterminals
      rhs.find_all { |item| NonTerminal === item }
    end
  end

  Choice = Struct.new(:items) do
    include Enumerable

    def each(&block)
      items.each { |item| item.each(&block) }
    end

    def inspect
      items.map(&:inspect).join(' | ')
    end
  end

  Sequence = Struct.new(:items) do
    include Enumerable

    def each(&block)
      items.each { |item| item.each(&block) }
    end

    def inspect
      items.map(&:inspect).join(' ')
    end
  end

  Empty = Class.new {
    include Enumerable

    def each
      yield self
    end

    def name
      'ε'
    end

    alias :inspect :name
  }.new

  NonTerminal = Struct.new(:name) do
    include Enumerable

    def each
      yield self
    end

    alias :inspect :name
  end

  Terminal = Struct.new(:name) do
    include Enumerable

    def each
      yield self
    end

    alias :inspect :name
  end

  def inspect
    width = rules.map { |rule| rule.lhs.name.size }.max
    rules.map { |rule| rule.inspect(width) }.join("\n")
  end

  def start_symbol
    rules.first.lhs
  end

  def start_rules
    rules_for(start_symbol)
  end

  def rules_for(nonterminal)
    rules.find_all { |rule| rule.lhs == nonterminal }
  end

  def split_choices
    split_rules = rules.flat_map do |rule|
      case rule.rhs
      when Choice
        rule.rhs.items.map { |item| Rule.new(rule.lhs, item) }
      else
        rule
      end
    end
    Grammar.new(split_rules)
  end

  def join_choices
    table = Hash.new { |h, k| h[k] = [] }

    rules.each do |rule|
      table[rule.lhs] << rule.rhs
    end

    new_rules = table.map do |key, rules|
      Rule.new(key, rules.size == 1 ? rules.first : Choice.new(rules))
    end
    Grammar.new(new_rules)
  end

  def clean
    remove_non_productive_rules.remove_unreachable_nonterminals
  end

  def remove_non_productive_rules
    productive_rules = Set.new
    productive_terms = Set.new

    rule_set = Set.new(rules)

    productive_rules = Algo.closure(productive_rules) do |known, new|
      unknown = rule_set - known

      unknown.find_all do |rule|
        productive = rule.rhs.all? do |atom|
          case atom
          when NonTerminal then productive_terms.member?(atom)
          when Terminal    then true
          when Empty       then true
          end
        end

        productive_terms.add(rule.lhs) if productive
        productive
      end
    end

    productive_rules &= rule_set
    Grammar.new(productive_rules.to_a)
  end

  def remove_unreachable_nonterminals
    reachable_terms = [start_symbol]

    reachable_terms = Algo.closure(reachable_terms) do |known, new|
      new.flat_map { |symbol| rules_for(symbol).flat_map(&:nonterminals) }
    end

    reachable_rules = rules.find_all { |rule| reachable_terms.member?(rule.lhs) }
    Grammar.new(reachable_rules)
  end

  def to_cnf(prep = true)
    if prep
      return split_choices.remove_epsilon_rules.remove_unit_rules.clean.to_cnf(false)
    end

    term_index = split_index = 1

    new_rules = rules.flat_map do |rule|
      next [rule] if Terminal === rule.rhs

      items = rule.rhs.items
      rules = []

      items = items.map do |item|
        next item unless Terminal === item
        symbol = NonTerminal.new("T#{term_index}")
        term_index += 1
        rules << Rule.new(symbol, item)
        symbol
      end

      rest = items[0 ... -1].inject do |symbol, item|
        lhs = NonTerminal.new("N#{split_index}")
        split_index += 1
        rules.unshift Rule.new(lhs, Sequence.new([symbol, item]))
        lhs
      end

      rules.unshift Rule.new(rule.lhs, Sequence.new([rest, items.last]))
      rules
    end

    Grammar.new(new_rules)
  end

  def remove_epsilon_rules
    primes    = {}
    new_rules = rules

    Algo.closure(find_empties(rules)) do |known, new|
      new_rules = new.inject(new_rules) do |rules, symbol|
        primed = NonTerminal.new(symbol.name + "'")
        primes[symbol] = primed

        rules.flat_map do |rule|
          split_rule_on_empty(rule, symbol, primed)
        end
      end
      find_empties(new_rules)
    end

    primed_rules = primes.flat_map do |from, to|
      rules = new_rules.find_all { |rule| rule.lhs == from and rule.rhs != Empty }
      rules.map { |rule| Rule.new(to, rule.rhs) }
    end

    new_rules = Set.new(new_rules + primed_rules).entries

    unknown_keys = primes.values - primed_rules.map(&:lhs)
    new_rules.delete_if { |rule| unknown_keys.include? rule.rhs }

    Grammar.new(new_rules)
  end

  def remove_unit_rules
    new_rules = rules

    Algo.closure(find_units(rules)) do |known, new|
      new_rules = new_rules.flat_map do |rule|
        next [rule] if Sequence === rule.rhs or Terminal === rule.rhs
        next [] if rule.lhs == rule.rhs

        new_rules.find_all { |r| r.lhs == rule.rhs }.map do |right|
          Rule.new(rule.lhs, right.rhs)
        end
      end
      find_units(new_rules)
    end

    Grammar.new(new_rules)
  end

private

  def find_units(rules)
    rules.reject { |rule| Sequence === rule.rhs }
  end

  def find_empties(rules)
    rules.find_all { |rule| rule.rhs == Empty }.map(&:lhs)
  end

  def split_rule_on_empty(rule, symbol, primed)
    return [rule] unless rule.rhs.entries.include?(symbol)

    if rule.rhs == symbol
      return [primed, Empty].map { |rhs| Rule.new(rule.lhs, rhs) }
    end

    [].tap do |rules|
      primed_items = rule.rhs.items.map { |t| t == symbol ? primed : t }
      rules << Rule.new(rule.lhs, Sequence.new(primed_items))

      indexes = primed_items.each_index.find_all { |i| primed_items[i] == primed }

      indexes.each do |index|
        reduced = primed_items.take(index) + primed_items.drop(index + 1)
        reduced = (reduced.size == 1) ? reduced.first : Sequence.new(reduced)
        rules << Rule.new(rule.lhs, reduced)
      end
    end
  end
end

require_relative './grammar/builder'
require_relative './grammar/parser'
