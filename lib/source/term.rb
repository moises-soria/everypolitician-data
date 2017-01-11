require_relative 'plain_csv'

module Source
  class Term < PlainCSV
    def to_popolo
      { events: events }
    end

    private

    def events
      as_table.map do |row|
        {
          id:              row[:id][/\//] ? row[:id] : "term/#{row[:id]}",
          name:            row[:name],
          start_date:      row[:start_date],
          end_date:        row[:end_date],
          identifiers:     row[:wikidata].to_s.empty? ? nil : [{
            scheme:     'wikidata',
            identifier: row[:wikidata]
          }],
          classification:  'legislative period',
        }.reject { |_, v| v.to_s.empty? }
      end
    end
  end
end
