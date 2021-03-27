require 'json'
require 'fileutils'
require 'securerandom'
require 'time'
require 'byebug'

class TurtlJoplinConverter
  def initialize(file)
    @data = JSON.parse(File.open(file).read)
    @ids = []
    @tags = []
  end

  def call
    extract_data
    convert_data
    write_joplin_raw_data
  end

  private

  def extract_data
    extract_spaces && extract_boards && extract_files_data && extract_notes
  end

  def extract_spaces
    puts 'Extracting Spaces from Turtl data...'
    @spaces = @data['spaces'].each_with_object([]) do |space, array|
      array << {
        id: space['id'],
        title: space['title']
      }
    end
  end

  def extract_boards
    puts 'Extracting Boards from Turtl data...'
    @boards = @data['boards'].each_with_object([]) do |board, array|
      array << {
        id: board['id'],
        title: board['title'],
        space_id: board['space_id']
      }
    end
  end

  def extract_files_data
    puts 'Extracting Files from Turtl data...'
    @files_data = @data['files'].each_with_object([]) do |file, array|
      array << {
        id: file['id'],
        data: file['data']
      }
    end
  end

  def extract_notes
    puts 'Extracting Notes from Turtl data...'
    @notes = @data['notes'].each_with_object([]) do |note, array|
      array << {
        id: note['id'],
        board_id: note['board_id'],
        file: note['has_file'] ? merge_file(note['file'], note['id']) : nil,
        space_id: note['space_id'],
        tags: note['tags'],
        markdown: convert_markdown(note['text']),
        title: note['title'],
        type: note['type']
      }
    end
  end

  def merge_file(file, id)
    file.merge(data: @files_data.select { |file_data| file_data[:id] == id })
  end

  def convert_markdown(markdown)
    markdown.gsub('__', '**').gsub('---', '* * *')
  end

  def convert_data
    convert_spaces && convert_boards && convert_notes && convert_tags
  end

  def convert_spaces
    puts 'Converting Spaces to Joplin data...'
    @joplin_spaces = @spaces.map do |space|
      {
        id: generate_id,
        title: space[:title],
        turtl_id: space[:id],
        parent_id: nil,
        type_: 2
      }
    end
  end

  def convert_boards
    puts 'Converting Boards to Joplin data...'
    @joplin_boards = @boards.map do |board|
      {
        id: generate_id,
        title: board[:title],
        turtl_id: board[:id],
        parent_id: @joplin_spaces.select { |space| space[:turtl_id] == board[:space_id] }.first[:id],
        type_: 2
      }
    end
  end

  def convert_notes
    puts 'Converting Notes to Joplin data...'
    @joplin_notes = @notes.map do |note|
      {
        id: generate_id,
        title: note[:title],
        content: note[:markdown],
        turtl_id: note[:id],
        tags: store_tags(note[:tags]),
        parent_id: select_note_parent(note),
        type_: 1
      }
    end
  end

  def select_note_parent(note)
    parent = @joplin_boards.select { |board| board[:turtl_id] == note[:board_id] }.first
    return parent[:id] if parent

    @joplin_spaces.select { |space| space[:turtl_id] == note[:space_id] }.first[:id]
  end

  def store_tags(tags)
    return [] if tags.none?

    @tags.push(tags)
    tags
  end

  def convert_tags
    puts 'Converting Tags to Joplin data...'
    @joplin_tags = @tags.flatten.uniq.map do |tag|
      {
        id: generate_id,
        title: tag,
        parent_id: nil,
        type_: 5
      }
    end
  end

  def common_joplin_params
    {
      id: generate_id,
      encryption_cipher_text: nil,
      encryption_applied: 0,
      is_shared: 0,
      created_time: Time.now.utc.iso8601,
      updated_time: Time.now.utc.iso8601,
      user_created_time: Time.now.utc.iso8601,
      user_updated_time: Time.now.utc.iso8601
    }
  end

  def generate_id
    hex = SecureRandom.hex
    @ids.include?(hex) ? generate_id : @ids.push(hex) && hex
  end

  def write_joplin_raw_data
    FileUtils.mkdir_p('raw/resources')
    write_spaces && write_boards && write_notes && write_tags && write_tag_joins
  end

  def write_spaces
    puts 'Exporting Spaces as Joplin markdown files...'

    @joplin_spaces.each do |space|
      File.write("raw/#{space[:id]}.md", notebook_joplin_format(space).strip)
    end
  end

  def write_boards
    puts 'Exporting Boards as Joplin markdown files...'

    @joplin_boards.each do |board|
      File.write("raw/#{board[:id]}.md", notebook_joplin_format(board).strip)
    end
  end

  def write_notes
    puts 'Exporting Notes as Joplin markdown files...'

    @joplin_notes.each do |note|
      File.write("raw/#{note[:id]}.md", note_joplin_format(note).strip)
    end
  end

  def write_tags
    puts 'Exporting Tags as Joplin markdown files...'

    @joplin_tags.each do |tag|
      File.write("raw/#{tag[:id]}.md", tag_joplin_format(tag).strip)
    end
  end

  def write_tag_joins
    @joplin_notes.select { |note| note[:tags].any? }.each do |note|
      # note[:tags] = ["foo", "bar"]
      note[:tags].each do |tag_title|
        tag_id = @joplin_tags.select { |joplin_tag| joplin_tag[:title] == tag_title }.first[:id]
        tag_join_id = generate_id
        File.write("raw/#{tag_join_id}.md", tag_join_joplin_format(tag_join_id, tag_id, note[:id]).strip)
      end
    end
  end

  def tag_join_joplin_format(tag_join_id, tag_id, note_id)
    <<~MD
      id: #{tag_join_id}
      note_id: #{note_id}
      tag_id: #{tag_id}
      #{timestamps_md}#{metadata_md}type_: 6
    MD
  end

  def notebook_joplin_format(notebook)
    <<~MD
      #{notebook[:title]}
      
      id: #{notebook[:id]}
      #{timestamps_md}#{metadata_md}parent_id: #{notebook[:parent_id]}
      type_: #{notebook[:type_]}
    MD
  end

  def note_joplin_format(note)
    <<~MD
      #{note[:title]}

      #{note[:content]}
      
      id: #{note[:id]}
      parent_id: #{note[:parent_id]}
      #{timestamps_md}#{notes_md}#{metadata_md}type_: #{note[:type_]}
    MD
  end

  def tag_joplin_format(tag)
    <<~MD
      #{tag[:title]}
      
      id: #{tag[:id]}
      #{timestamps_md}#{metadata_md}parent_id:
      type_: #{tag[:type_]}
    MD
  end



  def timestamps_md
    <<~TIME
      created_time: #{Time.now.utc.iso8601}
      updated_time: #{Time.now.utc.iso8601}
    TIME
  end

  def metadata_md
    <<~META
      user_created_time: #{Time.now.utc.iso8601}
      user_updated_time: #{Time.now.utc.iso8601}
      encryption_cipher_text:
      encryption_applied: 0
      is_shared: 0
    META
  end

  def notes_md
    <<~NOTES
      is_conflict: 0
      latitude: 0.00000000
      longitude: 0.00000000
      altitude: 0.0000
      author:
      source_url:
      is_todo: 0
      todo_due: 0
      todo_completed: 0
      source: joplin-desktop
      source_application: net.cozic.joplin-desktop
      application_data:
      order: 0
      markup_language: 1
    NOTES
  end
end

unless ARGV.length == 1
  puts 'Pass the file as an argument'
  exit
end

TurtlJoplinConverter.new(ARGV[0]).call
