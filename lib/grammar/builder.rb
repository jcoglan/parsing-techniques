class Grammar
  class Builder

    def build_grammar(t, a, b, el)
      Grammar.new(el[1].elements.map(&:rule))
    end

    def build_rule(t, a, b, el)
      Rule.new(el[0], el[4])
    end

    def build_choice(t, a, b, el)
      items = [el[0]] + el[1].elements.map(&:alternative)
      Choice.new(items)
    end

    def build_sequence(t, a, b, el)
      items = [el[0]] + el[1].elements.map(&:item)
      Sequence.new(items)
    end

    def build_empty(*)
      Empty.new
    end

    def build_nonterminal(t, a, b, *)
      NonTerminal.new(t[a ... b])
    end

    def build_terminal(t, a, b, *)
      Terminal.new(t[a ... b])
    end

  end
end
