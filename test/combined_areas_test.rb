require 'test_helper'
require_relative '../lib/combined_areas'

describe CombinedAreas do
  subject { CombinedAreas.new }
  let(:uuid_regex) { /^\w{8}-(\w{4}-){3}\w{12}$/ }

  it 'adds a single area' do
    subject.add_area('wikidata-areas', id: 'Q3296251', name: 'Anvard')
    out = subject.as_json.first
    out[:uuid].must_match uuid_regex
    out[:type].must_equal 'wikidata-areas'
    out[:name].must_equal 'Anvard'
    out[:id].must_equal 'Q3296251'
  end
end
