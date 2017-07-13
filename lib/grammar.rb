require_relative './algo'
require_relative './tree'
require_relative './rule'
require_relative './choice'
require_relative './sequence'
require_relative './empty'
require_relative './non_terminal'
require_relative './terminal'

Grammar = Struct.new(:rules) do
  def self.parse(source)
    Grammar::Parser.parse(source, :actions => Grammar::Builder.new)
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
    rules.each { |rule| table[rule.lhs] << rule.rhs }

    new_rules = table.map { |key, rules| Rule.new(key, Choice.unit(rules)) }
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
      next [rule] unless rule.sequence?

      items       = rule.rhs.items
      term_rules  = []
      split_rules = []

      items = items.map do |item|
        next item unless item.terminal?
        lhs = NonTerminal.new("T#{term_index}")
        term_index += 1
        term_rules << Rule.new(lhs, item)
        lhs
      end

      prefix = items[0 ... -1].inject do |symbol, item|
        lhs = NonTerminal.new("N#{split_index}")
        split_index += 1
        split_rules <<  Rule.new(lhs, Sequence.new([symbol, item]))
        lhs
      end

      top = Rule.new(rule.lhs, Sequence.new([prefix, items.last]))
      [top] + split_rules + term_rules
    end

    Grammar.new(new_rules)
  end

  def remove_epsilon_rules
    primes    = {}
    new_rules = rules

    Algo.closure(new_rules.find_all(&:empty?).map(&:lhs)) do |known, new|
      new_rules = new.inject(new_rules) do |rules, symbol|
        primed = symbol.primed
        primes[symbol] = primed

        rules.flat_map do |rule|
          split_rule_on_empty(rule, symbol, primed)
        end
      end
      new_rules.find_all(&:empty?).map(&:lhs)
    end

    primed_rules = primes.flat_map do |from, to|
      rules = new_rules.reject(&:empty?).find_all { |rule| rule.for?(from) }
      rules.map { |rule| Rule.new(to, rule.rhs) }
    end

    new_rules = Set.new(new_rules + primed_rules).entries

    unknown_keys = primes.values - primed_rules.map(&:lhs)
    new_rules.delete_if { |rule| unknown_keys.include? rule.rhs }

    Grammar.new(new_rules)
  end

  def remove_unit_rules
    new_rules = rules

    Algo.closure(new_rules.find_all(&:unit?)) do |known, new|
      new_rules = new_rules.flat_map do |rule|
        next [] if rule.self_loop?
        next [rule] unless rule.unit?

        new_rules.find_all { |r| r.for? rule.rhs }.map do |right|
          Rule.new(rule.lhs, right.rhs)
        end
      end
      new_rules.find_all(&:unit?)
    end

    Grammar.new(new_rules)
  end

private

  def split_rule_on_empty(rule, symbol, primed)
    return [rule] unless rule.contains?(symbol)

    if rule.is? symbol
      return [primed, Empty].map { |rhs| Rule.new(rule.lhs, rhs) }
    end

    [].tap do |rules|
      seq = rule.rhs.replace(symbol, primed)
      rules << Rule.new(rule.lhs, seq)

      indexes = seq.indexes(primed)

      indexes.each do |index|
        reduced = seq.items.take(index) + seq.items.drop(index + 1)
        rules << Rule.new(rule.lhs, Sequence.unit(reduced))
      end
    end
  end
end

require_relative './grammar/builder'
require_relative './grammar/parser'
