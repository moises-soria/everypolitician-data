require_relative 'csv'

module Source
  class OCD < CSV
    def fields
      %i(area area_id)
    end

    def fuzzy_match?
      i(:merge)[:fuzzy]
    end

    def overrides
      return {} unless i(:merge)
      return {} unless i(:merge).key? :overrides
      i(:merge)[:overrides]
    end

    def generate
      i(:generate)
    end
  end

  class OCD::IDs < OCD
  end

  class OCD::Names < OCD
  end
end
