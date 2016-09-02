#-----------------------------------------------------------------------
# Update the `stats.json` file for a Legislature
#-----------------------------------------------------------------------

STATSFILE = Pathname.new('unstable/stats.json')

namespace :stats do
  task regenerate: 'ep-popolo-v1.0.json' do
    popolo = Everypolitician::Popolo.read('ep-popolo-v1.0.json')
    stats = StatsFile.new(popolo: popolo, position_filter: POSITION_FILTER).stats

    STATSFILE.dirname.mkpath
    STATSFILE.write(JSON.pretty_generate(stats))
  end
end
