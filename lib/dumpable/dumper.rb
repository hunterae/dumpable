module Dumpable
  class Dumper
    attr_accessor :dumpee, :options, :id_padding, :dumps

    def initialize(dumpee, options={})
      @dumpee = dumpee
      @options = Dumpable.config.merge(options || {})
      @id_padding = @options[:id_padding] || (@dumpee.class.respond_to?(:dumpable_options) && @dumpee.class.dumpable_options[:id_padding]) || Dumpable.config.id_padding
      @dumps = @options[:dumps] || (@dumpee.class.respond_to?(:dumpable_options) && @dumpee.class.dumpable_options[:dumps])
      @lines = []
    end

    def dump
      recursive_dump(@dumpee, @dumps)
      @lines << generate_insert_query(@dumpee)
    end

    def self.dump(*records_and_collections)
      options = records_and_collections.extract_options!
      lines = []
      records_and_collections.each do |record_or_collection|
        if record_or_collection.is_a?(Array) || record_or_collection.is_a?(ActiveRecord::Relation) || (record_or_collection.is_a?(Class) && record_or_collection.ancestors.include?(ActiveRecord::Base))
          record_or_collection = record_or_collection.all if record_or_collection.is_a?(Class) && record_or_collection.ancestors.include?(ActiveRecord::Base)
          record_or_collection.each do |object|
            lines << new(object, options).dump
          end
        else
          lines << new(record_or_collection, options).dump
        end
      end
      Dumpable::FileWriter.write(lines.flatten.compact, options)
    end

    private
    def recursive_dump(object, dumps)
      if dumps.nil?

      elsif dumps.is_a?(Array)
        dumps.each do |mini_dump|
          recursive_dump(object, mini_dump)
        end
      elsif dumps.is_a?(Hash)
        dumps.each do |key, value|
          recursive_dump(object, key)
          Array(object.send(key)).each { |child| recursive_dump(child, value) }
        end
      elsif dumps.is_a?(Symbol) || dumps.is_a?(String)
        Array(object.send(dumps)).each do |child_object|
          reflection = object.class.reflections[dumps.to_sym]
          if reflection.macro == :belongs_to
            object.send("#{reflection.association_foreign_key}=", object.id + @id_padding)
          elsif [:has_many, :has_one].include? reflection.macro
            if reflection.respond_to?(:foreign_key)
              child_object.send("#{reflection.foreign_key}=", object.id + @id_padding)
            else
              child_object.send("#{reflection.primary_key_name}=", object.id + @id_padding)
            end
          end
          @lines << generate_insert_query(child_object)
        end
      end
    end

    # http://invisipunk.blogspot.com/2008/04/activerecord-raw-insertupdate.html
    def generate_insert_query(object)
      skip_columns = Array(@options[:skip_columns] || (object.class.respond_to?(:dumpable_options) && object.class.dumpable_options[:skip_columns])).map(&:to_s)
      cloned_attributes = object.attributes.clone
      return nil unless cloned_attributes["id"].present?
      cloned_attributes["id"] += @id_padding
      key_values = cloned_attributes.collect do |key,value|
        [key, dump_value_string(value)] unless skip_columns.include?(key.to_s)
      end.compact
      keys = key_values.collect{ |item| "`#{item[0]}`" }.join(", ")
      values = key_values.collect{ |item| item[1].to_s }.join(", ")

      "INSERT INTO #{object.class.table_name} (#{ keys }) VALUES (#{ values });"
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
        when "ActiveSupport::HashWithIndifferentAccess"
          "'#{value.to_yaml.gsub(/'/, "\\\\'")}'"
        else
          "'#{value}'"
      end
    end
  end
end