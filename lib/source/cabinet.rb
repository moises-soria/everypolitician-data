require_relative 'plain_csv'

module Source
  class Cabinet < PlainCSV
    def filtered(position_map:)
      wanted = position_map.cabinet_ids
      as_table.select { |r| wanted.include? r[:position] }
    end
  end
end
