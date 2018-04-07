# frozen_string_literal: true

namespace :report do
  task :missing_wikidata do
    popolo = Everypolitician::Popolo.read('ep-popolo-v1.0.json')
    popolo.latest_term.memberships.reject { |mem| mem.person.wikidata }.uniq(&:person).each do |mem|
      puts '%s (%s) %s' % [mem.person.name, mem.person.id, mem.sources.first&.[](:url)]
    end
  end
end
