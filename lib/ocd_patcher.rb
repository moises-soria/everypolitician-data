class OcdPatcher
  attr_reader :row, :ocd_ids, :warnings, :ocd_instruction

  def initialize(row, ocd_instruction)
    @row = row
    @ocd_ids = ocd_instruction.as_table
    @ocd_instruction = ocd_instruction
    @warnings = []
  end

  def patched
    row.dup.tap do |r|
      if ocd_instruction.generate == 'area'
        if ocds.key?(r[:area_id])
          r[:area] = ocds[r[:area_id]].first[:name]
        elsif r[:area_id].to_s.empty?
          warnings << "    No area_id given for #{r[:uuid]}"
        else
          # :area_id was given but didn't resolve to an OCD ID.
          warnings << "    Could not resolve area_id #{r[:area_id]} for #{r[:uuid]}"
        end
      end
    end
  end

  def ocds
    @ocds ||= ocd_ids.group_by { |r| r[:id] }
  end
end
