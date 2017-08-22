#!/usr/bin/env ruby

require 'csv'
require 'pp'

module Parsing
  # https://stackoverflow.com/a/26131816/351149
  def self.struct_from_hash(struct_class, hash)
    struct_class.new(*hash.values_at(*struct_class.members))
  end

  def self.parse_dict_file(struct_class, path, cols)
    r = {}

    CSV.foreach(path, col_sep: "\t", quote_char: "\x00") do |raw_row|
      row = cols.zip(raw_row).to_h
      key, values_hash = yield row
      r[key] = struct_from_hash(struct_class, values_hash)
    end

    r
  end
end

class LojbanDict
  Gismu = Struct.new(:word, :rafsis, :gloss, :definition)
  Cmavo = Struct.new(:word, :selmaho, :gloss, :definition, :rafsis)
  Rafsi = Struct.new(:rafsi, :word)

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

    @selmahoste = Hash.new{ |h, k| h[k] = [] }
    mahoste.values.each do |cmavo|
      selmahoste[cmavo.selmaho].push cmavo
    end

    @glosses = Hash.new{ |h, k| h[k] = [] }
    [mahoste.values, gihuste.values].each do |words|
      words.each do |word|
        glosses[word.gloss].push word
      end
    end
  end

  def decompose_lujvo(lujvo)
    lujvo = lujvo.gsub("y", "")

    return [] if lujvo.length < 3

    # Full gismu at end of word
    gismu = gihuste[lujvo]
    return [[lujvo, gismu]] if gismu

    # Regular 4-letter or 3-letter rafsi
    [4, 3].each do |rafsi_length|
      next unless lujvo.length >= rafsi_length

      rafsi = rafste[lujvo[0, rafsi_length]]
      next unless rafsi

      r = [[rafsi.rafsi, rafsi.word]]
      return r if lujvo.length == rafsi_length

      rest = decompose_lujvo(lujvo[rafsi_length, lujvo.length])
      return r + rest unless rest.empty?
    end

    # Hyphen r or hyphen n
    if ["r", "n"].include?(lujvo[0, 1])
      return decompose_lujvo(lujvo[1, lujvo.length])
    end

    # Invalid lujvo
    return []
  end
end

dict = LojbanDict.new(File.dirname(__FILE__))
pp dict.decompose_lujvo("pavyseljirna")
