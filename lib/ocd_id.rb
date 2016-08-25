class OcdId
  attr_reader :ocd_ids
  attr_reader :overrides
  attr_reader :area_ids

  def initialize(ocd_ids, overrides, fuzzy)
    @ocd_ids = ocd_ids
    @overrides = overrides
    @fuzzy = fuzzy
    @area_ids = {}
  end

  def from_name(name)
    area_ids[name] ||= area_id_from_name(name)
  end

  private

  def area_id_from_name(name)
    area = override(name) || finder(name)
    return if area.nil?
    warn '  Matched Area %s to %s' % [name.yellow, area[:name].to_s.green] unless area[:name].include? " #{name} "
    area[:id]
  end

  def override(name)
    override_id = overrides[name]
    return if override_id.nil?
    { name: name, id: override_id }
  end

  def finder(name)
    if fuzzy?
      fuzzer.find(name.to_s, must_match_at_least_one_word: true)
    else
      ocd_ids.find { |i| i[:name] == name }
    end
  end

  def fuzzy?
    @fuzzy
  end

  def fuzzer
    @fuzzer ||= FuzzyMatch.new(ocd_ids, read: :name)
  end
end
