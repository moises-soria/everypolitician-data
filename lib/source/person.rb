require_relative 'csv'

module Source
  class Person < CSV
    def person_data?
      true
    end
  end
end
