require_relative 'plain_csv'

module Source
  class Area < PlainCSV
    def to_popolo
      {
        areas: as_table.map do |area|
          {
            id:          reconciliation_data[area[:id]],
            identifiers: [{
              identifier: area[:id],
              scheme:     'wikidata',
            },],
            other_names: area.keys.select { |k| k.to_s.start_with? 'name__' }.map do |k|
              {
                lang: k.to_s[/name__(\w+)/, 1],
                name: area[k],
                note: 'multilingual',
                # TODO: credit the source
                # source: 'wikidata',
              }
            end,
          }
        end.reject { |a| a[:id].nil? },
      }
    end

    private

    def reconciliation_file
      'sources/' + i(:merge)[:reconciliation_file]
    end

    def reconciliation_data
      @rd ||= ::CSV.table(reconciliation_file).map do |r|
        [r[:wikidata], r[:id]]
      end.to_h
    end
  end
end
