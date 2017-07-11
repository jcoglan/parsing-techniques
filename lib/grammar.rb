require 'set'

Grammar = Struct.new(:rules) do
  def self.parse(source)
    Grammar::Parser.parse(source, :actions => Grammar::Builder.new)
  end

  Rule = Struct.new(:lhs, :rhs) do
    def inspect
      "#{lhs.name} → #{rhs.inspect}"
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

  class Empty
    include Enumerable

    def each
      yield self
    end

    def name
      'ε'
    end

    alias :inspect :name
  end

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
    rules.map(&:inspect).join("\n")
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

  def clean
    remove_non_productive_rules.remove_unreachable_nonterminals
  end

  def remove_non_productive_rules
    productive_rules = Set.new
    productive_terms = Set.new

    rule_set = Set.new(rules)

    productive_rules = closure(productive_rules) do |known, new|
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
    reachable_terms = Set.new([start_symbol])

    reachable_terms = closure(reachable_terms) do |known, new|
      new.flat_map { |symbol| rules_for(symbol).flat_map(&:nonterminals) }
    end

    reachable_rules = rules.find_all { |r| reachable_terms.member?(r.lhs) }
    Grammar.new(reachable_rules)
  end

  def closure(match_set)
    new_members = match_set

    loop do
      new_members = Set.new(yield match_set, new_members)
      break if new_members.empty?

      new_members -= match_set
      match_set   += new_members
    end
    match_set
  end
end

require_relative './grammar/builder'
require_relative './grammar/parser'
