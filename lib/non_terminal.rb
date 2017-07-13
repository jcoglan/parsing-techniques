NonTerminal = Struct.new(:name) do
  include Enumerable

  def each
    yield self
  end

  alias :inspect :name

  def primed
    NonTerminal.new(name + "'")
  end

  def terminal?
    false
  end
end
