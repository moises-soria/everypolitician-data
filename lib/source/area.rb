require_relative 'json'

module Source
  class Area < JSON
    def to_popolo
      { areas: as_json.map { |k, v| v.merge(id: k.to_s) } }
    end
  end
end
