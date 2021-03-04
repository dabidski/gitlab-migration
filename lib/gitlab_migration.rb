require "pivotal_export_parser"
require "gitlab"
require "csv"
require "json"
require "byebug"

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

  def self.migrate_pivotal_project(project_folder:, stories_csv_path:, gitlab_project:, gitlab_epic_id:)
    PivotalExportParser.parse(stories_csv_path) do |story_data|
      comments = story_data[:comment]
      owners = story_data[:owned_by]
      story_data[:project] = gitlab_project
      story_data[:epic_id] = gitlab_epic_id
      
      issue = convert_to_issue(story_data)
      issue.save
    end
  end

  private

  def self.convert_to_issue(data)
    Issue.new(data[:project], data[:title]).tap do |issue|
      # Set mappable fields
      issue.created_at = data[:created_at]
      issue.description = data[:description]
      issue.epic_id = data[:epic_id]
      issue.weight = data[:estimate]

      # Add unmappable fields as a note
      other_data = data.slice(:id, :type, :requested_by, :accepted_at, :url)
      table_rows_str = other_data.inject([]) do |memo, (key, value)|
        memo.push("|#{key}|#{value}|") if value
        memo
      end.join("\r\n")
      table_rows_str += "|Owners|#{data[:owned_by].join(', ')}|" if data[:owned_by].any?
      table_str = "#### Pivotal Data\r\n| Field | Value |\r\n| ------ | ------ |\r\n"
      issue.build_note(nil, table_str + table_rows_str, data[:created_at])

      # Set status label
      if data[:current_state] != "accepted"
        issue.state = :opened
        issue.labels.push(convert_pivotal_status(data[:current_state]))
      else
        issue.state = :closed
      end

      # Set pivotal id as label
      issue.labels.push("piv:id:#{data[:id]}")

      # Set old pivotal labels
      issue.labels.push(*convert_pivotal_labels(data[:labels])) if data[:labels]

      # Add all old comments as notes
      data[:comment].each_with_index do |comment, idx|
        # pivotal export did not include timestamp for comments so we need to
        # add a second between each comment to ensure we get correct ordering
        issue.build_note(comment.author, comment.text, comment.created_at + idx + 1)
      end if data[:comment]
    end
  end

  def self.convert_pivotal_labels(string_label)
    string_label.split(',').map{ |label| "piv:#{label.strip}" }
  end

  def self.convert_pivotal_status(state)
    "Sts::#{STATUS_TO_LABEL_MAPPING[state.downcase]}"
  end

  class Issue
    def initialize(project, title)
      @project = project
      @title = title
      @notes = []
      @labels = []
    end

    attr_accessor :id, :project, :title, :labels, :notes, :weight,
                  :epic_id, :description, :state, :created_at

    def build_note(author, text, created_at)
      Note.new(self, author, text, created_at).tap do |note|
        notes << note
      end
    end

    def save
      # Create issue
      attrs = {
        description: description,
        created_at: created_at.iso8601,
        labels: labels.join(","),
        epic_id: epic_id
      }
      result = Gitlab.create_issue(project, title, attrs)
      @id = result["iid"]

      # Save all notes
      notes.each(&:save)

      # Close issue if required
      if state == :closed
        Gitlab.edit_issue(project, id, state_event: 'close')
      end
    end
  end

  class Note
    def initialize(issue, author, text, created_at)
      @issue = issue
      @author = author
      @text = text
      @created_at = created_at
    end

    attr_accessor :issue, :author, :text, :created_at

    def save
      raise "issue not yet saved" if issue.id.nil?
      Gitlab.create_issue_note(issue.project, issue.id, body, created_at: created_at.iso8601)
    end

    private

    # We're not able to set the user so the note is prepended with author name
    def body
      if author
        "**#{author}**: #{text}"
      else
        text
      end
    end
  end
end
