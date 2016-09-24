require_relative 'plain_csv'

module Source
  class Gender < PlainCSV
    def converter(h)
      h == 'uuid' ? :string : :int
    end

    def fields
      %i(gender)
    end
  end
end
