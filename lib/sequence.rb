Sequence = Struct.new(:items) do
  include Enumerable

  def self.unit(items)
    items.size == 1 ? items.first : new(items)
  end

  def each(&block)
    items.each { |item| item.each(&block) }
  end

  def inspect
    items.map(&:inspect).join(' ')
  end

  def indexes(term)
    items.each_index.find_all { |i| items[i] == term }
  end

  def replace(needle, replacement)
    Sequence.new(items.map { |t| t == needle ? replacement : t })
  end
end
