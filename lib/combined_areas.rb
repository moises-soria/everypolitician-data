class CombinedAreas
  def initialize
    @areas = []
  end

  def add_area(area)
    area[:uuid] = SecureRandom.uuid
    areas << area
  end

  def as_json
    areas
  end

  private

  attr_reader :areas
end
