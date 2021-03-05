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
          :owned_by => nil,
          :accepted_at => DateTime.parse("Nov 2, 2018")
        },
        "161714920" => {
          :title => "Unable to add documents to Ocorian Room",
          :labels => "ocorian, qa2",
          :type => "bug",
          :current_state => "accepted",
          :owned_by => ["Amy Bath", "David Sumulong"],
          :accepted_at => DateTime.parse("Nov 6, 2018")
        },
        "161580247" => {
          :title => "Expose inherited metadata fields for documents & folders [part 3 - with inheritance]",
          :labels => "api, seeunity",
          :type => "feature",
          :current_state => "accepted",
          :owned_by => ["David Sumulong"],
          :accepted_at => DateTime.parse("Nov 16, 2018")
        },
        "170098998" => {
          :title => "^^ Waiting on go ahead from JLee ^^",
          :labels => "",
          :type => "release",
          :current_state => "unstarted",
          :owned_by => nil,
          :accepted_at => nil
        }
      }

      expected = expected_data[story[:id]] or raise "Cannot find story with ID: #{story[:id]}"
      expected.keys.each do |key|
        expected[key].nil? ? assert_nil(story[key]) : assert_equal(expected[key], story[key])
      end
    end
    assert_equal 4, count
  end
end