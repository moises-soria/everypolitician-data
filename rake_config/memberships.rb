
desc 'Remap memberships ids'
namespace :memberships do
  task :remap_ids, [:from, :to] do |_, args|
    @INSTRUCTIONS.sources_of_type('membership').each do |source|
      file = source.mapfile
      data = remap(file, args)
      file.rewrite(data)
    end
  end
end

private

def remap(file, args)
  data = file.mapping
  abort "No existing data for #{args[:from]}" unless data[args[:from]]
  abort "Already have data for #{args[:to]}" if data[args[:to]]
  data[args[:to]] = data.delete(args[:from])
  data
end
