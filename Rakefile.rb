
require 'fileutils'
require 'pathname'
require 'pry'
require 'require_all'
require 'tmpdir'
require 'json'

require_rel 'lib'

@HOUSES = FileList['data/*/*/Rakefile.rb'].map { |f| f.pathmap '%d' }.reject { |p| File.exist? "#{p}/WIP" }

def json_from(json_file)
  statements = 0
  json = JSON.load(File.read(json_file), lambda do |h|
    statements += h.values.select { |v| v.class == String }.count if h.class == Hash
  end, symbolize_names: true, create_additions: false)
  [json, statements]
end

def json_load(file)
  raise "No such file #{file}" unless File.exist? file
  JSON.parse(File.read(file), symbolize_names: true)
end

def json_write(file, json)
  File.write(file, JSON.pretty_generate(json))
end


desc 'Install country-list locally'
task 'countries.json' do
  # By default we build every country, but if EP_COUNTRY_REFRESH is set
  # we only build any country that contains that string. For example:
  #    EP_COUNTRY_REFRESH=Latvia be rake countries.json
  to_build = ENV['EP_COUNTRY_REFRESH'] || 'data'

  countries = @HOUSES.group_by { |h| h.split('/')[1] }.select do |_, hs|
    hs.any? { |h| h.include? to_build }
  end

  data = json_load('countries.json') rescue {}
  # If we know we'll need data for every country directory anyway,
  # it's much faster to pass the single directory 'data' than a list
  # of every country directory:
  commit_metadata = file_to_commit_metadata(
    to_build == 'data' ? ['data'] : countries.values.flatten
  )

  countries.each do |c, hs|
    country = EveryPolitician::Country::Metadata.new(
      country: c,
      dirs: hs,
      commit_metadata: commit_metadata,
    ).stanza
    data[data.find_index { |c| c[:name] == country[:name] }] = country
  end
  File.write('countries.json', JSON.pretty_generate(data.sort_by { |c| c[:name] }.to_a))
end

require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList['test/*_test.rb']
  t.verbose = true
end

task default: :test
