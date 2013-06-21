require 'active_support'
require 'active_record'

module Dumpable
  extend ActiveSupport::Concern

  mattr_accessor :dumpable_id_padding
  @@dumpable_id_padding = 0

  def dump(options={})
    id_padding = options[:id_padding] || self.class.dumpable_id_padding

    dumps = options[:dumps] || self.class.dumps

    recursive_dump(self, id_padding, dumps)
    puts generate_insert_query(id_padding)
  end

  # http://invisipunk.blogspot.com/2008/04/activerecord-raw-insertupdate.html
  def generate_insert_query(id_padding)
    cloned_attributes = self.attributes.clone
    cloned_attributes["id"] += id_padding
    key_vals = cloned_attributes.collect{ |key,value| [key, dump_value_string(value)] }
    "INSERT INTO #{self.class.table_name} " +
    "( #{key_vals.collect{ |item| item[0].to_s }.join(", ") } ) " + 
    "VALUES( #{key_vals.collect{ |item| item[1].to_s }.join(", ") } );"
  end

  private
  def recursive_dump(object, id_padding, dumps)
    if dumps.nil?

    elsif dumps.is_a?(Array)
      dumps.each do |mini_dump|
        recursive_dump(object, id_padding, mini_dump)
      end
    elsif dumps.is_a?(Hash)
      dumps.each do |key, value|
        recursive_dump(object, id_padding, key)
        Array(object.send(key)).each { |child| recursive_dump(child, id_padding, value) }
      end
    elsif dumps.is_a?(Symbol) || dumps.is_a?(String)
      Array(object.send(dumps)).each do |child_object|
        reflection = object.class.reflections[dumps]
        if reflection.macro == :belongs_to
          object.send("#{reflection.association_foreign_key}=", object.id + id_padding)
        elsif [:has_many, :has_one].include? reflection.macro
          child_object.send("#{reflection.association_primary_key}=", object.id + id_padding)
        end
        puts child_object.send(:generate_insert_query, id_padding)
      end
    end
  end

  # http://invisipunk.blogspot.com/2008/04/activerecord-raw-insertupdate.html
  def dump_value_string(value)
    case value.class.to_s
      when "Time"
        "'#{value.strftime("%Y-%m-%d %H:%M:%S")}'"
      when "NilClass"
        "NULL"
      when "Fixnum"
        value
      when "String"
        "'#{value.gsub(/'/, "\\\\'")}'"
      when "FalseClass"
        '0'
      when "TrueClass"
        '1'
      else
        "'#{value}'"
    end
  end

  module ClassMethods
    def dumpable(options={})
      self.class_eval do
        cattr_accessor :dumpable_id_padding, :dumps
      end
      self.dumpable_id_padding = options[:id_padding] || Dumpable.dumpable_id_padding
      self.dumps = options[:dumps]
    end
  end
end

ActiveRecord::Base.send :include, Dumpable