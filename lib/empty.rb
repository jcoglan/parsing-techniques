Empty = Class.new {
  include Enumerable

  def each
    yield self
  end

  def name
    'ε'
  end

  alias :inspect :name

  def terminal?
    true
  end
}.new
