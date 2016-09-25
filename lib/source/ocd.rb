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
    def merged_with(csv)
      ocds = as_table.group_by { |r| r[:id] }
      csv.each do |r|
        if ocds.key?(r[:area_id])
          r[:area] = ocds[r[:area_id]].first[:name]
        elsif r[:area_id].to_s.empty?
          add_warning "    No area_id given for #{r[:uuid]}"
        else
          # :area_id was given but didn't resolve to an OCD ID.
          add_warning "    Could not resolve area_id #{r[:area_id]} for #{r[:uuid]}"
        end
      end
      csv
    end
  end
end
