Choice = Struct.new(:items) do
  include Enumerable

  def self.unit(items)
    items.size == 1 ? items.first : Choice.new(items)
  end

  def each(&block)
    items.each { |item| item.each(&block) }
  end

  def inspect
    items.map(&:inspect).join(' | ')
  end
end
