class SourceCSV
  def initialize(str)
    @raw = str
  end

  def ids
    grouped.keys
  end

  def rows(*kk)
    kk.flat_map { |k| grouped[k] }
  end

  private

  attr_reader :raw

  def as_csv
    @csv ||= CSV.parse(raw, headers: true, header_converters: :symbol)
  end

  def grouped
    @grouped ||= as_csv.group_by { |r| r[:id] }
  end
end

class SourceHistory
  # Given a Source file, look at the prior version in git history and
  # provide access to information that has vanished since then
  def initialize(source)
    @source = source
  end

  def vanishing_data
    old.rows(*vanishing_ids)
  end

  private

  attr_reader :source

  def repo_root
    Pathname.new('../../..').realpath
  end

  def full_pathname
    source.pathname.realpath.relative_path_from(repo_root)
  end

  def old
    @old ||= SourceCSV.new(`git show @~1:#{full_pathname}`)
  end

  def cur
    @cur ||= SourceCSV.new(source.pathname.read)
  end

  def vanishing_ids
    old.ids - cur.ids
  end
end

desc 'report on vanishing data from a given file'
namespace :missing_data do
  # TODO: add a parallel task for the idmap files
  task :memberships, [:filename] do |_, args|
    wanted = @SOURCES.find { |s| s.filename.to_s.include? args[:filename] } ||
             abort("No suitable source matching '#{args[:filename]}'")
    source = SourceHistory.new(wanted)
    vanished = source.vanishing_data
    puts vanished.first.headers.join(',')
    puts vanished
  end
end
