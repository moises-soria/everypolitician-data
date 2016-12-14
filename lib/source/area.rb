require_relative 'plain_csv'
require 'field_serializer'

module Source
  class Area < PlainCSV
    class Row
      include FieldSerializer

      def initialize(r, reconciliation_data)
        @area = r
        @reconciliation_data = reconciliation_data
      end

      field :id do
        reconciliation_data[area[:id]]
      end

      field :identifiers do
        [
          {
            identifier: area[:id],
            scheme:     'wikidata',
          },
        ]
      end

      field :other_names do
        area.keys.select { |k| k.to_s.start_with? 'name__' }.map do |k|
          {
            lang: k.to_s[/name__(\w+)/, 1],
            name: area[k],
            note: 'multilingual',
            # TODO: credit the source
            # source: 'wikidata',
          }
        end
      end

      private

      attr_reader :area, :reconciliation_data
    end

    def to_popolo
      {
        areas: area_data,
      }
    end

    private

    def area_data
      as_table.map { |area| Row.new(area, reconciliation_data).to_h }
              .reject { |a| a[:id].nil? }
    end

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
