class PivotalExportParser
  require 'csv'
  PIVOTAL_PATH = File.join(Rails.root, "test", "data")
  SINGLE_COLUMN_HEADERS = [:id, :title, :labels, :type, :estimate, :current_state, :created_at,
                           :accepted_at, :requested_by, :description, :url]
  MULTIPLE_COLUMN_HEADERS = [:owned_by, :comment]

  Comment = Struct.new(:author, :created_at, :text)

  def self.parse(filename)
    header_converters = [:downcase, :symbol]
    CSV.foreach(File.join(PIVOTAL_PATH, filename), headers: true, header_converters: header_converters) do |row|
      issue_data = {}
      row.headers.each_with_index do |header, idx|
        if SINGLE_COLUMN_HEADERS.include?(header)
          if header == :labels
            issue_data[header] = parse_labels(row[idx])
          elsif header == :current_state
            issue_data[header] = format_status(row[idx])
          else
            issue_data[header] = (header == :accepted_at || header == :created_at) ? DateTime.parse(row[idx]) : row[idx]
          end
        elsif MULTIPLE_COLUMN_HEADERS.include?(header)
          issue_data[header] ||= []
          if !row[idx].nil?
            issue_data[header] << (header == :comment ? parse_comment(row[idx]) : row[idx])
          end
        end
      end
      yield issue_data
    end
  end

  private

  def self.parse_comment(comment)
    if match = comment.match(/\(([^()]+) - (\w{3} \d{1,2}, \d{4})\)$/)
      Comment.new(match[1], DateTime.parse(match[2]), comment.chomp!(match[0]))
    else
      Comment.new(nil, nil, comment)
    end
  end

  def self.parse_labels(string_label)
    string_label.split(',').map{ |label| "piv:#{label.strip}" }
  end

  def self.format_status(state)
    status_labels = {
      "unstarted" => "Unstarted",
      "started" => "Dev Started",
      "finished" => "Tl code review",
      "delivered" => "For deploy to prod",
      "rejected" => "Update post code review",
      "accepted" => "Closed"
    }

    "Sts::#{status_labels[state]}"
  end
end 