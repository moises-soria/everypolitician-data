require_relative 'uuid_map'

module Source
  class Base
    # Instantiate correct subclass based on instructions
    def self.instantiate(i)
      raise "Missing `type` in #{i}" unless i.key? :type
      return Source::Membership.new(i)  if i[:type] == 'membership'
      return Source::Person.new(i)      if i[:type] == 'person'
      return Source::Wikidata.new(i)    if i[:type] == 'wikidata'
      return Source::Group.new(i)       if i[:type] == 'group'
      return Source::OCD.new(i)         if i[:type] == 'ocd'
      return Source::Area.new(i)        if i[:type] == 'area-wikidata'
      return Source::Gender.new(i)      if i[:type] == 'gender'
      return Source::Positions.new(i)   if i[:type] == 'wikidata-positions'
      return Source::Elections.new(i)   if i[:type] == 'wikidata-elections'
      return Source::Term.new(i)        if i[:type] == 'term'
      return Source::Corrections.new(i) if i[:type] == 'corrections'
      raise "Don't know how to handle #{i[:type]} files (#{i})"
    end

    def initialize(i)
      @instructions = i
    end

    def i(k)
      @instructions[k.to_sym]
    end

    def type
      i(:type)
    end

    def merge_instructions
      i(:merge)
    end

    def person_data?
      false
    end

    def recreateable?
      i(:create)
    end

    # private
    REMAP = {
      area:            %w(constituency region district place),
      area_id:         %w(constituency_id region_id district_id place_id),
      biography:       %w(bio blurb),
      birth_date:      %w(dob date_of_birth),
      blog:            %w(weblog),
      cell:            %w(mob mobile cellphone),
      chamber:         %w(house),
      death_date:      %w(dod date_of_death),
      end_date:        %w(end ended until to),
      executive:       %w(post),
      family_name:     %w(last_name surname lastname),
      fax:             %w(facsimile),
      gender:          %w(sex),
      given_name:      %w(first_name forename),
      group:           %w(party party_name faction faktion bloc block org organization organisation),
      group_id:        %w(party_id faction_id faktion_id bloc_id block_id org_id organization_id organisation_id),
      image:           %w(img picture photo photograph portrait),
      name:            %w(name_en),
      patronymic_name: %w(patronym patronymic),
      phone:           %w(tel telephone),
      source:          %w(src),
      start_date:      %w(start started from since),
      term:            %w(legislative_period),
      website:         %w(homepage href url site),
    }.each_with_object({}) { |(k, vs), mapped| vs.each { |v| mapped[v] = k } }

    def remap(str)
      REMAP[str.to_s] || str.to_sym
    end

    def filename
      i(:file)
    end

    def pathname
      Pathname.new(filename)
    end

    def file_contents
      File.read(filename)
    end
  end

  class Positions < JSON
  end

  class Corrections < PlainCSV
  end
end
