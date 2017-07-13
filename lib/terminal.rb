Terminal = Struct.new(:name) do
  include Enumerable

  def each
    yield self
  end

  alias :inspect :name

  def terminal?
    true
  end
end
