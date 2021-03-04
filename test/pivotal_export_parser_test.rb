require 'test_helper'

class PivotalExportParserTest < ActiveSupport::TestCase

  expected_data = {
    "161580207" => {
      :title => "Expose extra metadata fields for documents & folders [part 1 - simple fields]",
      :labels => [],
      :type => "feature",
      :current_state => "Sts::Closed",
      :owned_by => []
    },
    "161714920" => {
      :title => "Unable to add documents to Ocorian Room",
      :labels => ["piv:ocorian", "piv:qa2"],
      :type => "bug",
      :current_state => "Sts::Closed",
      :owned_by => ["Amy Bath", "David Sumulong"]
    },
    "161580247" => {
      :title => "Expose inherited metadata fields for documents & folders [part 3 - with inheritance]",
      :labels => ["piv:api", "piv:seeunity"],
      :type => "feature",
      :current_state => "Sts::Closed",
      :owned_by => ["David Sumulong"] 
    } 
  }

  test "can parse csv" do
    count = 0
    PivotalExportParser.parse("pivotal_export_parser_test_data.csv") do |story|
      count += 1
      expected = expected_data[story[:id]] or raise "Cannot find story with ID: #{story[:id]}"
      expected.keys.each do |key|
        assert_equal expected[key], story[key]
      end
    end
    assert_equal 3, count
  end
end