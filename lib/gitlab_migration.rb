require "pivotal_export_parser"
require "gitlab"
require "csv"
require "json"

module GitlabMigration
  VERSION = "0.1.0"

  STATUS_TO_LABEL_MAPPING = {
    "unstarted" => "Unstarted",
    "started" => "Dev Started",
    "finished" => "TL code review",
    "delivered" => "For Deploy to Prod",
    "rejected" => "Update Post Code Review",
    "accepted" => "Closed"
  }

  def self.migrate_pivotal_project(project_folder:, gitlab_project_name:, epic_name:)
    PivotalExportParser.parse(project_folder) do |story_data|
      comments = story_data[:comment]
      owners = story_data[:owned_by]
      story_data[:project_name] = gitlab_project_name
      [:id, :title, :labels, :type, :estimate, :current_state, :created_at,
        :accepted_at, :requested_by, :description, :url]
      
      issue = convert_to_issue(story_data)
    end
  end

  private

  def self.convert_to_issue(data)
    Issue.new(data[:project_name], data[:title]).tap do |issue|
      # Add unmappable fields as a note
      other_data = data.slice(:id, :type, :estimate, :requested_by, :accepted_at, :url)
      other_data_str = other_data.inject("") do |str, (key, value)|
        str << "#{key}: #{value}"
      end
      issue.build_note("PivotalData", other_data_str, data[:created_at])

      # Set status label
      if data[:current_state] != "accepted"
        issue.state = :opened
        issue.labels << convert_pivotal_status(data[:current_state])
      else
        issue.state = :closed
      end

      # Set pivotal id as label
      issue.labels.push("piv:id:#{id}")

      # Set old pivotal labels
      issue.labels.push(*convert_pivotal_labels(data[:labels]))

      # Add all old comments as notes
      issue.notes = data[:comments].map do |comment|
        issue.build_note(comment.author, comment.text, comment.created_at)
      end
    end
  end

  def self.convert_pivotal_labels(string_label)
    string_label.split(',').map{ |label| "piv:#{label.strip}" }
  end

  def self.convert_pivotal_status(state)
    "Sts::#{STATUS_TO_LABEL_MAPPING[state.downcase]}"
  end

  class Issue
    def initialize(project:, title:)
      @project_name = project
      @title = title
      @notes = []
      @labels = []
    end

    attr_accessor :id, :project_name, :title, :labels, :notes,
                  :epic_name, :description, :state, :created_at

    def build_note(author, text, created_at)
      Note.new(self, comment.author, comment.text, comment.created_at).tap do |note|
        notes << note
      end
    end

    def save
      # Create issue
      attrs = {
        description: description,
        created_at: created_at.iso8601
      }
      result = Gitlab.create_issue(project_name, title, attrs)
      id = result["id"]

      # Save all notes
      notes.each(&:save)

      # Close issue if required
      if state == :closed
        Gitlab.edit_issue(project_name, id, title, state_event: 'close')
      end
    end
  end

  class Note
    def initialize(issue:, author:, text:, created_at:)
      @issue = issue
      @author = author,
      @text = text
      @created_at = created_at
    end

    attr_accessor :issue, :author, :text, :created_at

    def save
      raise "issue not yet saved" if issue.id.nil?
      Gitlab.create_issue_note(issue.project_name, issue.id, body, created_at: created_at.iso8601)
    end

    private

    # We're not able to set the user so the note is prepended with author name
    def body
      "#{author}: #{text}"
    end
  end
end
