require 'test_helper'

class PivotalExportParserTest < Minitest::Test
  def test_it_can_parse_csv
    count = 0
    PivotalExportParser.parse("test/data/pivotal_export_parser_test_data.csv") do |story|
      count += 1
          
      expected_data = {
        "161580207" => {
          :title => "Expose extra metadata fields for documents & folders [part 1 - simple fields]",
          :labels => "",
          :type => "feature",
          :current_state => "accepted",
          :owned_by => []
        },
        "161714920" => {
          :title => "Unable to add documents to Ocorian Room",
          :labels => "ocorian, qa2",
          :type => "bug",
          :current_state => "accepted",
          :owned_by => ["Amy Bath", "David Sumulong"]
        },
        "161580247" => {
          :title => "Expose inherited metadata fields for documents & folders [part 3 - with inheritance]",
          :labels => "api, seeunity",
          :type => "feature",
          :current_state => "accepted",
          :owned_by => ["David Sumulong"]
        }
      }

      expected = expected_data[story[:id]] or raise "Cannot find story with ID: #{story[:id]}"
      expected.keys.each do |key|
        assert_equal expected[key], story[key]
      end
    end
    assert_equal 3, count
  end
end