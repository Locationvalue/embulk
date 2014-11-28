
module QuickLoad
  require 'quickload/error'

  class PluginRegistry
    def initialize(category, search_prefix)
      @category = category
      @search_prefix = search_prefix
      @map = {}
    end

    attr_reader :category

    def register(type, value)
      type = type.to_sym
      @map[type] = value
    end

    def lookup(type)
      type = type.to_sym
      if value = @map[type]
        return value
      end
      search(type)
      if value = @map[type]
        return value
      end
      raise ConfigError, "Unknown #{@category} plugin '#{type}'."
    end

    def search(type)
      path = "#{@search_prefix}#{type}"

      # prefer LOAD_PATH than gems
      paths = $LOAD_PATH.map { |lp|
        lpath = File.expand_path(File.join(lp, "#{path}.rb"))
        File.exist?(lpath) ? lpath : nil
      }.compact.sort + [path]  # add [path] to search from Java classpath
      paths.each do |path|
        # prefer newer version
        begin
          require path
          return
        rescue LoadError
        end
      end

      # search gems
      if defined?(::Gem::Specification) && ::Gem::Specification.respond_to?(:find_all)
        specs = Gem::Specification.find_all { |spec|
          spec.contains_requirable_file? path
        }

        # prefer newer version
        specs = specs.sort_by { |spec| spec.version }
        if spec = specs.last
          spec.require_paths.each { |lib|
            file = "#{spec.full_gem_path}/#{lib}/#{path}"
            require file
          }
        end

        # backward compatibility for rubygems < 1.8
      elsif defined?(::Gem) && ::Gem.respond_to?(:searcher)
        #files = Gem.find_files(path).sort
        specs = Gem.searcher.find_all(path)

        # prefer newer version
        specs = specs.sort_by { |spec| spec.version }
        specs.reverse_each { |spec|
          files = Gem.searcher.matching_files(spec, path)
          unless files.empty?
            require files.first
            break
          end
        }
      end
    end
  end
end