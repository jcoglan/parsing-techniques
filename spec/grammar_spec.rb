require 'minitest/autorun'
require 'grammar'

describe Grammar do
  describe :clean do
    let :grammar do
      Grammar.parse <<-GMR
        S -> A B | D E
        A -> a
        B -> b C
        C -> c
        D -> d F
        E -> e
        F -> f D
      GMR
    end

    it 'removes nonproductive rules and unreachable nonterminals' do
      grammar.split_choices.clean.must_equal Grammar.parse(<<-GMR)
        S -> A B
        A -> a
        B -> b C
        C -> c
      GMR
    end
  end

  describe :remove_epsilon_rules do
    it 'removes epsilon rules from a simple grammar' do
      grammar = Grammar.parse <<-GMR
        S -> L a M
        L -> L M | ε
        M -> M M | ε
      GMR
      grammar.split_choices.remove_epsilon_rules.join_choices.must_equal Grammar.parse(<<-GMR)
        S  -> L' a M' | L' a | a M' | a
        L  -> L' M' | L' | M' | ε
        M  -> M' M' | M' | ε
        L' -> L' M' | L' | M'
        M' -> M' M' | M'
      GMR
    end

    it 'removes epsilon rules from a more complex grammar' do
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
      grammar.split_choices.remove_epsilon_rules.join_choices.must_equal Grammar.parse(<<-GMR)
        Number   -> Integer | Real
        Integer  -> Digit | Integer Digit
        Real     -> Integer Fraction Scale' | Integer Fraction
        Fraction -> . Integer
        Scale    -> e Sign Integer | ε
        Digit    -> 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9
        Sign     -> + | -
        Empty    -> ε
        Scale'   -> e Sign Integer
      GMR
    end
  end

  describe :to_cnf do
    let(:grammar) do
      Grammar.parse <<-GMR
        Number   -> Integer | Real
        Integer  -> Digit | Integer Digit
        Real     -> Integer Fraction Scale
        Fraction -> . Integer
        Scale    -> e Sign Integer | Empty
        Digit    -> 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9
        Sign     -> + | -
        Empty    -> ε
      GMR
    end

    it 'converts a grammar to Chomsky normal form' do
      grammar.to_cnf.join_choices.must_equal Grammar.parse(<<-GMR)
        Number   -> 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | Integer Digit | N1 Scale' | Integer Fraction
        N1       -> Integer Fraction
        Integer  -> 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | Integer Digit
        Fraction -> T1 Integer
        T1       -> .
        Digit    -> 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9
        Sign     -> + | -
        Scale'   -> N2 Integer
        N2       -> T2 Sign
        T2       -> e
      GMR
    end
  end
end
