
module EveryPolitician
  class Country
    # The metadata for a country, included in countries.json
    class Metadata
      def initialize(country:, dirs:, commit_metadata:)
        @country = country
        @dirs = dirs
        @commit_metadata = commit_metadata
      end

      def stanza
        meta_file = dirs.first + '/../meta.json'
        meta = File.exist?(meta_file) ? JSON.load(File.open(meta_file)) : {}
        name = meta['name'] || country.tr('_', ' ')
        slug = country.tr('_', '-')
        {
          name:         name,
          # Deprecated - will be removed soon!
          country:      name,
          code:         meta['iso_code'].upcase,
          slug:         slug,
          legislatures: dirs.map do |h|
            json_file = h + '/ep-popolo-v1.0.json'
            name_file = h + '/names.csv'
            remote_source = 'https://cdn.rawgit.com/everypolitician/everypolitician-data/%s/%s'
            popolo, statement_count = json_from(json_file)
            sha, lastmod = commit_metadata[json_file].values_at :sha, :timestamp
            lname = name_from(popolo)
            lslug = h.split('/').last.tr('_', '-')
            {
              name:                lname,
              slug:                lslug,
              sources_directory:   "#{h}/sources",
              popolo:              json_file,
              popolo_url:          remote_source % [sha, json_file],
              names:               name_file,
              lastmod:             lastmod,
              person_count:        popolo[:persons].size,
              sha:                 sha,
              legislative_periods: terms_from(popolo, h).each do |t|
                term_csv_sha = commit_metadata[t[:csv]][:sha]
                t[:csv_url] = remote_source % [term_csv_sha, t[:csv]]
              end,
              statement_count:     statement_count,
            }
          end,
        }
      end

      private

      attr_reader :country, :dirs, :commit_metadata
    end
  end
end
