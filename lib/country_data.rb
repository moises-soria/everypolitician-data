
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
        {
          name:         name,
          # Deprecated - will be removed soon!
          country:      name,
          code:         meta['iso_code'].upcase,
          slug:         slug,
          legislatures: dirs.map { |h| Legislature::Metadata.new(dir: h, commit_metadata: commit_metadata).stanza },
        }
      end

      private

      attr_reader :country, :dirs, :commit_metadata

      def meta_file
        dirs.first + '/../meta.json'
      end

      def meta_json
        JSON.load(File.open(meta_file))
      end

      def meta
        @meta ||= File.exist?(meta_file) ? meta_json : {}
      end

      def name
        meta['name'] || country.tr('_', ' ')
      end

      def slug
        country.tr('_', '-')
      end
    end
  end

  class Legislature
    class Metadata
      def initialize(dir:, commit_metadata:)
        @dir = dir
        @commit_metadata = commit_metadata
      end

      def stanza
        json_file = dir + '/ep-popolo-v1.0.json'
        name_file = dir + '/names.csv'
        remote_source = 'https://cdn.rawgit.com/everypolitician/everypolitician-data/%s/%s'
        popolo, statement_count = json_from(json_file)
        sha, lastmod = commit_metadata[json_file].values_at :sha, :timestamp
        lname = name_from(popolo)
        lslug = dir.split('/').last.tr('_', '-')
        {
          name:                lname,
          slug:                lslug,
          sources_directory:   "#{dir}/sources",
          popolo:              json_file,
          popolo_url:          remote_source % [sha, json_file],
          names:               name_file,
          lastmod:             lastmod,
          person_count:        popolo[:persons].size,
          sha:                 sha,
          legislative_periods: terms_from(popolo, dir).each do |t|
            term_csv_sha = commit_metadata[t[:csv]][:sha]
            t[:csv_url] = remote_source % [term_csv_sha, t[:csv]]
          end,
          statement_count:     statement_count,
        }
      end

      private

      attr_reader :dir, :commit_metadata
    end
  end
end
