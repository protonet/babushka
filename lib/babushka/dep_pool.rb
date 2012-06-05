module Babushka
  class DepPool

    attr_reader :skipped_count

    def initialize source
      clear!
      @skipped_count = 0
      @source = source
    end

    def count
      @dep_hash.length
    end
    
    def names
      @dep_hash.keys
    end
    def deps
      @dep_hash.values
    end
    def for spec
      spec.respond_to?(:name) ? @dep_hash[spec.name] : @dep_hash[spec]
    end

    def add name, in_opts, block
      if self.for name
        @skipped_count += 1
        self.for name
      else
        Dep.new name, @source, in_opts, block
      end
    end

    def clear!
      @dep_hash = {}
    end
    def uncache!
      deps.each {|dep| dep.send :uncache! }
    end
    def define_deps!
      deps.each {|dep| dep.define! }
    end

    def register dep
      raise "There is already a registered dep called '#{dep.name}'." if @dep_hash.has_key?(dep.name)
      @dep_hash[dep.name] = dep
    end

  end
end
