Rule = Struct.new(:lhs, :rhs) do
  def inspect(width = nil)
    padding = width ? width - lhs.name.size : 0
    "#{lhs.name}#{' ' * padding} → #{rhs.inspect}"
  end

  def for?(symbol)
    lhs == symbol
  end

  def is?(symbol)
    rhs == symbol
  end

  def contains?(symbol)
    rhs.any? { |term| term == symbol }
  end

  def empty?
    rhs == Empty
  end

  def unit?
    NonTerminal === rhs
  end

  def sequence?
    Sequence === rhs
  end

  def self_loop?
    lhs == rhs
  end

  def match?(token)
    value = (Terminal === rhs) ? rhs.name : rhs
    value == token
  end

  def nonterminals
    rhs.find_all { |item| NonTerminal === item }
  end
end
