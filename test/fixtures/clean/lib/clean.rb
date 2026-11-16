# Code that a reader would keep as is. typegap reports none of it: each line
# is a shape a rule once reported by mistake.
class Item
  attr_reader :name

  def initialize(name) = @name = name
  def to_s = name
end

class Clean
  attr_reader :status, :name, :note, :flag, :items, :table, :numbers

  def initialize
    @status = :open
    @name = ""
    @note = nil
    @flag = nil
    @items = []
    @table = {}
    @numbers = []
    @cache = nil
  end

  def run
    # RBS types Hash#[] and Array#first as never nil; they are nil when the key or element is missing.
    table[:a]&.succ
    items.first&.upcase
    puts "none" if table[:a].nil?
    # An instance variable can be nil before it is set, whatever its type says.
    @cache ||= name
    # A literal on the right of || is a default for nil, not boolean logic: it keeps false.
    shown = note || "none"
    on = flag.nil? ? false : flag
    # An assertion on a literal widens its type, as a later `widened = true` needs.
    widened = false #: bool
    # A conversion with a block does something the bare call does not.
    pairs = items.to_h { [_1, 1] }
    "#{name}: #{note || "-"}, #{Item.new(name)}, #{numbers.size}"
    case status
    when :open then 1
    when :closed then 2
    end
    case note
    when String then note
    end
    sorted = numbers.sort
    by_size = items.sort_by(&:size)
    return if on
    upcased = name.upcase
    p [shown, pairs, upcased, sorted, by_size, widened]
  end
end
