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
end
