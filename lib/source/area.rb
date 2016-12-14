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
        area.select { |k, v| v && k.to_s.start_with?('name__') }.map do |k, v|
          {
            lang: k.to_s[/name__(\w+)/, 1],
            name: v,
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

    def reconciliation_file
      Pathname.new('sources/') + i(:merge)[:reconciliation_file]
    end

    private

    def area_data
      as_table.map { |area| Row.new(area, reconciliation_data).to_h }
              .reject { |a| a[:id].nil? }
    end

    def reconciliation_data
      raise 'Area reconciliation file missing' unless reconciliation_file.exist?
      @rd ||= ::CSV.table(reconciliation_file).map do |r|
        [r[:wikidata], r[:id]]
      end.to_h
    end
  end
end
