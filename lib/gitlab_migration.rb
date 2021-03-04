require "pivotal_export_parser"
require "gitlab"
require "csv"

module GitlabMigration
  VERSION = "0.1.0"

  def self.migrate_project(project_path:, name:)
    PivotalExportParser.parse(project_path) do |story_data|
      comments = story_data[:comment]
      owners = story_data[:owned_by]
      [:id, :title, :labels, :type, :estimate, :current_state, :created_at,
        :accepted_at, :requested_by, :description, :url]
        
    end
  end

  class Issue
    def initialize(attrs={})

    end

    def save

    end
  end
end
