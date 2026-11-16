class Point
  attr_reader :x
  def initialize(x) = @x = x
end

class Shop
  attr_reader :status, :name, :note, :flag, :items, :points, :mixed, :opts

  def old = 0
  def count = 0
  def log(msg) = nil
  def lookup = nil
  def ready? = "yes"
  def chain
    self
  end
  def size = 1
  def size=(v)
    v
  end
  def pick(v) = nil
  def wide = ""
  def twice = ""

  def run
    n = count
    old
    name&.upcase
    n.nil?
    if n then nil end
    name || "x"
    flag || true
    n.is_a?(Integer)
    n.is_a?(String)
    name.respond_to?(:upcase)
    flag2 = (n > 1)
    flag2 == true
    name.to_s
    "#{name}"
    "note: #{note}"
    "items: #{items}"
    "point: #{Point.new(1)}"
    case status
    when :open then 1
    end
    status == :pending
    name.strip
    items.map { _1 }
    v = log("a")
    s = lookup #: String
    t = name #: String
    points.sort
    mixed.sort
    items.select { _1 }.first
    [*opts]
    if n.nil? then puts "never" end
    p [n, v, s, t]
  end
end
