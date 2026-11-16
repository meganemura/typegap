# frozen_string_literal: true
# rbs_inline: enabled

module Typegap
  # One place where the types and the code disagree, or where the code does
  # what the types make unnecessary or impossible. It carries no severity: the
  # rule name says what kind of gap it is, and the reader decides whether the
  # code or the type is wrong.
  class Finding
    attr_reader :path #: String
    attr_reader :line #: Integer
    attr_reader :column #: Integer
    attr_reader :rule #: String
    attr_reader :message #: String

    # @rbs path: String
    # @rbs line: Integer
    # @rbs column: Integer
    # @rbs rule: String
    # @rbs message: String
    def initialize(path:, line:, column:, rule:, message:) #: void
      @path = path
      @line = line
      @column = column
      @rule = rule
      @message = message
    end

    #: () -> Array[String | Integer]
    def sort_key = [path, line, column, rule]

    #: () -> Hash[Symbol, String | Integer]
    def to_h = { path: path, line: line, column: column, rule: rule, message: message }

    #: () -> String
    def to_s = "#{path}:#{line}:#{column}: #{rule}: #{message}"
  end
end
