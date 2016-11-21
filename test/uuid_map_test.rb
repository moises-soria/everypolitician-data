require 'test_helper'
require_relative '../lib/uuid_map'

describe 'UUID Mapper' do
  let(:new_tempfile) do
    Pathname.new(Tempfile.new(['data-ids', '.csv']).path)
  end

  it "has nothing if the file doesn't exist" do
    UuidMapFile.new(Pathname.new('not/a/file')).mapping.must_be_empty
  end

  it 'has nothing in an empty tempfile' do
    UuidMapFile.new(new_tempfile).mapping.must_be_empty
  end

  it 'has new data after writing' do
    file = new_tempfile
    mapper = UuidMapFile.new(file)
    data = mapper.mapping
    data.must_be_empty
    data['fred'] = 'uuid-1'
    data['barney'] = 'uuid-2'
    mapper.rewrite(data)

    # read it back in again
    newmap = UuidMapFile.new(file)
    newmap.mapping.keys.count.must_equal 2
    newmap.uuid_for('barney').must_equal 'uuid-2'
    newmap.id_for('uuid-1').must_equal 'fred'
  end
end
