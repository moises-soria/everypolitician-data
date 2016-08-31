class CombinedAreas
  def initialize
    @areas = []
  end

  def add_area(type, area)
    area[:type] = type
    area[:uuid] = SecureRandom.uuid
    areas << area
  end

  def as_json
    areas
  end

  private

  attr_reader :areas
end
