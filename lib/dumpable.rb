require 'active_support'
require 'active_record'
require 'hashie'

module Dumpable
  autoload :ActiveRecordExtensions, "dumpable/active_record_extensions"
  autoload :Dumper,                 "dumpable/dumper"
  autoload :FileWriter,             "dumpable/file_writer"

  mattr_accessor :config
  @@config = Hashie::Mash.new
  @@config.id_padding = 0

  def self.dump(*records_and_collections)
    Dumpable::Dumper.dump(*records_and_collections)
  end

  # Default way to setup Dumpable
  def self.setup
    yield config
  end
end

ActiveRecord::Base.send :include, Dumpable::ActiveRecordExtensions