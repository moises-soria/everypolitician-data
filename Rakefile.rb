
require 'fileutils'
require 'pathname'
require 'pry'
require 'require_all'
require 'tmpdir'
require 'json'

require_rel 'lib'

@HOUSES = FileList['data/*/*/Rakefile.rb'].map { |f| f.pathmap '%d' }.reject { |p| File.exist? "#{p}/WIP" }

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
    country = Everypolitician::Country::Metadata.new(
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

desc "Go through the list of open pull requests and close any outdated ones"
task :close_old_pull_requests do
  require 'close_old_pull_requests'
  CloseOldPullRequests.clean.each do |pull_request|
    puts "Pull request #{pull_request.number} is outdated. (Newest pull request is #{pull_request.superseded_by.number})"
  end
end

desc "Post a summary of the pull request that's currently being built"
task :pull_request_summary do
  if ENV['TRAVIS_PULL_REQUEST'] == 'false'
    warn 'Not building a pull request, skipping pull_request_summary'
    next
  end
  require 'everypolitician/pull_request'
  repo_slug = ENV.fetch('TRAVIS_REPO_SLUG', 'everypolitician/everypolitician-data')
  pull_request_number = ENV['TRAVIS_PULL_REQUEST'] || ENV['PULL_REQUEST']
  abort 'error: Please supply a pull request number: ' \
    'bundle exec rake pull_request_summary PULL_REQUEST=12345' if pull_request_number.nil?
  body = Everypolitician::PullRequest::Summary.new(pull_request_number).as_markdown
  github = Octokit::Client.new(access_token: ENV['GITHUB_ACCESS_TOKEN'])
  begin
    github.add_comment(repo_slug, pull_request_number, body)
  rescue Octokit::Unauthorized
    abort 'unauthorized: Please set GITHUB_ACCESS_TOKEN in the environment ' \
      'and try again. https://github.com/settings/tokens'
  end
end
