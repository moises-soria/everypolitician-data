
desc 'Handle moved Wikidata'
namespace :wikidata do
  task :handle_move, [:from, :to] do |_, args|
    rfile = sources.find(&:is_wikidata?).reconciliation_file
    data = rfile.to_h
    abort "No existing data for #{args[:from]}" unless data[args[:from]]
    abort "Already have data for #{args[:to]}" if data[args[:to]]
    data[args[:to]] = data.delete(args[:from])
    rfile.write!(data)
  end
end
