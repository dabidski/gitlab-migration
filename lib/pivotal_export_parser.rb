class PivotalExportParser
  require 'csv'

  SINGLE_COLUMN_HEADERS = [:id, :title, :labels, :type, :estimate, :current_state, :created_at,
                           :accepted_at, :requested_by, :description, :url]
  MULTIPLE_COLUMN_HEADERS = [:owned_by, :comment]

  Comment = Struct.new(:author, :created_at, :text)

  def self.parse(filepath)
    header_converters = [:downcase, :symbol]
    CSV.foreach(filepath, headers: true, header_converters: header_converters) do |row|
      issue_data = {}
      row.headers.each_with_index do |header, idx|
        if SINGLE_COLUMN_HEADERS.include?(header)
          if (header == :accepted_at || header == :created_at)
            issue_data[header] = DateTime.parse(row[idx])
          else
            issue_data[header] = row[idx]
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
end 