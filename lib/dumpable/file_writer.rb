module Dumpable
  class FileWriter
    def self.write(lines, options)
      if options[:file]
        File.open(options[:file], "w") do |file|
          file.puts lines
        end
      else
        lines.each do |line|
          puts line
        end
      end
      nil
    end
  end
end