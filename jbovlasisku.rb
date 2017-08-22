#!/usr/bin/env ruby

require 'csv'
require 'highline'
require 'pp'

class WordStruct < Struct
  def formatted
    typename = self.class.name.gsub("Result", "").downcase
    "  <%= color(#{typename.inspect}, GREEN) %>:\n  #{format_content.gsub("\n", "\n  ")}"
  end

  def self.from_h(hash)
    # https://stackoverflow.com/a/26131816/351149
    new(*hash.values_at(*members))
  end
end

module Parsing
  def self.parse_dict_file(struct_class, path, cols)
    r = {}

    CSV.foreach(path, col_sep: "\t", quote_char: "\x00") do |raw_row|
      row = cols.zip(raw_row).to_h
      key, values_hash = yield row
      r[key] = struct_class.from_h(values_hash)
    end

    r
  end
end

Gismu = WordStruct.new(:word, :rafsis, :gloss, :definition) do
  def name; word; end

  def format_content
    definition
  end
end

Cmavo = WordStruct.new(:word, :selmaho, :gloss, :definition, :rafsis) do
  def name; word; end

  def format_content
    definition
  end
end

Rafsi = WordStruct.new(:rafsi, :word) do
  def name; rafsi; end

  def format_content
    word.formatted.gsub("\n", "\n  ")
  end
end

Gloss = WordStruct.new(:gloss, :word) do
  def name; gloss; end

  def format_content
    word.formatted.gsub("\n", "\n  ")
  end
end

LujvoResult = WordStruct.new(:word, :parts) do
  def name; word; end

  def format_content
    desc = parts.map do |part, word|
      "<%= color(#{part.inspect}, YELLOW) %>:\n#{word.formatted.gsub("\n", "\n  ")}"
    end
    
    desc.join("\n")
  end
end

SelmahoResult = WordStruct.new(:selmaho, :words) do
  def name; selmaho; end

  def format_content
    "SELMAHO"
  end
end

class LojbanDict
  attr_reader :gihuste, :mahoste, :selmahoste, :rafste, :glosses

  def initialize(dir)
    @gihuste = Parsing.parse_dict_file(Gismu, "#{dir}/gismu.dat", %i(word rafsis gloss definition)) do |row|
      [
        row[:word],
        row.merge(rafsis: row[:rafsis].to_s.split(" "))
      ]
    end
    
    @mahoste = Parsing.parse_dict_file(Cmavo, "#{dir}/cmavo.dat", %i(word selmaho gloss definition)) do |row|
      [
        row[:word],
        row.merge(rafsis: [])
      ]
    end

    @rafste = Parsing.parse_dict_file(Rafsi, "#{dir}/rafsi.dat", %i(rafsi word)) do |row|
      word_obj = gihuste[row[:word]] || mahoste[row[:word]]
      raise "Unable to find word #{row[:word]} for rafsi #{row[:rafsi]}" unless word_obj

      # Load rafsi for cmavo, they aren't included in cmavo.dat
      word_obj.rafsis.push(row[:rafsi]) if word_obj.is_a?(Cmavo)

      [
        row[:rafsi],
        row.merge(word: word_obj)
      ]
    end

    @selmahoste = {}
    mahoste.values.each do |cmavo|
      selmahoste[cmavo.selmaho] ||= []
      selmahoste[cmavo.selmaho].push cmavo
    end

    @glosses = {}
    [mahoste.values, gihuste.values].each do |words|
      words.each do |word|
        glosses[word.gloss] ||= []
        glosses[word.gloss].push Gloss.new(word.gloss, word)
      end
    end
  end

  def query(input)
    input = input.strip
    first_char = input[0, 1]
    if first_char == "/"
      query_definition_regex(input)
    elsif first_char =~ /[A-Z]/
      query_selmaho(input)
    else
      query_word(input)
    end
  end

  private

  def query_definition_regex(input)
  end

  def query_selmaho(input)
    input = input.upcase.gsub("H", "h")
    selmaho = selmahoste[input]
    selmaho.nil? ? [] : [SelmahoResult.new(input, selmaho)]
  end

  def query_word(input)
    input = input.downcase
    results = [gihuste[input], mahoste[input], rafste[input], glosses[input]].compact
    results = [query_lujvo(input)].compact if results.empty?
    return results
  end

  def query_lujvo(input)
    parts = decompose_lujvo(input)
    parts.nil? ? nil : LujvoResult.new(input, parts)
  end

  def decompose_lujvo(input)
    input = input.gsub("y", "")

    return [] if input.empty?
    return nil if input.length < 3

    # Full gismu at end of word
    gismu = gihuste[input]
    return [[input, gismu]] if gismu

    # Regular 4-letter or 3-letter rafsi
    [4, 3].each do |rafsi_length|
      next unless input.length >= rafsi_length

      rafsi = rafste[input[0, rafsi_length]]
      next unless rafsi

      r = [[rafsi.rafsi, rafsi.word]]
      return r if input.length == rafsi_length

      rest = decompose_lujvo(input[rafsi_length, input.length])
      return r + rest unless rest.nil?
    end

    # Hyphen r or hyphen n
    if ["r", "n"].include?(input[0, 1])
      return decompose_lujvo(input[1, input.length])
    end

    # Invalid lujvo
    return nil
  end
end

class UserInterface
  def initialize(dict)
    @dict = dict
    @cli = HighLine.new
  end

  def run
  end

  def handle(input)
    result = @dict.query(input)
    output = "<%= color(#{input.inspect}, WHITE) %>:\n#{format(result)}"
    @cli.say output
  end

  def format(result)
    return "<%= color('No results found', RED) %>" if result.empty?
    result.map{|r| r.formatted.gsub("\n", "\n  ") }.join("\n\n")
  end
end

dict = LojbanDict.new(File.dirname(__FILE__))
ui = UserInterface.new(dict)
if ARGV.length > 0
  ui.handle(ARGV.join(" "))
else
  ui.run
end
