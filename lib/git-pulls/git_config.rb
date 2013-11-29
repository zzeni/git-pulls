require 'git'

class GitConfig
  def initialize(*args)
    raw = begin
            Git.open('.').config
          rescue
            puts "Note: #{Dir.pwd} is not a github repository. Falling back to global config."
            Git.global_config
          end
    config = to_nested_hashes raw

    @_global_config = config.delete(:global) || {}
    @_config = config
  end

  def [](key)
    if @_config.has_key? key
      @_config[key]
    elsif @_global_config.has_key? key
      @_global_config[key]
    else
      raise "No such key: #{key}!"
    end
  end

  private
  def to_nested_hashes(config_hash)
    hashes = config_hash.map {|k,v| _to_nested_hashes(k.split('.') + [v])}
    hashes.inject(&:deep_merge)
  end

  def _to_nested_hashes(list)
    if list.size == 2
      { list[0].to_sym => list[1] }
    else
      { list.shift.to_sym => _to_nested_hashes(list) }
    end
  end
end

class ::Hash
  def deep_merge(second)
    merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
    self.merge(second, &merger)
  end
end
