module Dumpable
  module ActiveRecordExtensions
    extend ActiveSupport::Concern

    def dump(options={})
      Dumpable::Dumper.dump(self, options)
    end

    module ClassMethods
      def dumpable(options={})
        class_eval do
          cattr_accessor :dumpable_options
        end
        self.dumpable_options = options
      end

      def dump(options={})
        Dumpable::Dumper.dump(self, options)
      end
    end
  end
end