require_relative 'csv'

module Source
  class Membership < CSV
    def id_map
      id_mapper.mapping
    end

    def write_id_map_file!(data)
      id_mapper.rewrite(data)
    end

    def raw_table
      super.each do |r|
        # if the source has no ID, generate one
        r[:id] = r[:name].downcase.gsub(/\s+/, '_') if r[:id].to_s.empty?
      end
    end

    # Currently we just recognise a hash of k:v pairs to accept if matching
    # TODO: add 'reject' and more complex expressions
    def as_table
      return raw_table unless i(:filter)
      filter = ->(row) { i(:filter)[:accept].all? { |k, v| row[k] == v } }
      @_filtered ||= raw_table.select { |row| filter.call(row) }
    end

    private

    def id_mapper
      @map ||= UuidMapFile.new(id_map_file)
    end

    def id_map_file
      Pathname.new(filename.sub(/.csv$/, '-ids.csv'))
    end
  end
end
