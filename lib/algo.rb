require 'set'

module Algo
  def self.closure(matches)
    match_set   = Set.new(matches)
    new_members = match_set

    loop do
      new_members = Set.new(yield match_set, new_members) - match_set
      break if new_members.empty?

      match_set += new_members
    end

    match_set
  end

  def self.product(a, b)
    a.flat_map { |left| b.map { |right| yield left, right } }
  end
end
