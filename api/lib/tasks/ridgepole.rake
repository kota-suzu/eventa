namespace :ridgepole do
  desc "Apply schema definition"
  task apply: :environment do
    ridgepole("--apply")
  end

  desc "Export schema definition"
  task export: :environment do
    ridgepole("--export")
  end

  desc "Show difference between schema definition and DB"
  task diff: :environment do
    ridgepole("--diff")
  end

  desc "Create a new migration file"
  task :new_migration, [:name] => :environment do |_task, args|
    unless args.name
      puts "No name specified. Use rake ridgepole:new_migration[migration_name]"
      exit 1
    end

    timestamp = Time.now.strftime("%Y%m%d%H%M%S")
    path = "db/migrations/#{timestamp}_#{args.name}.rb"

    # ディレクトリが存在しない場合は作成
    FileUtils.mkdir_p("db/migrations")

    File.write(path, <<~RUBY)
      # Migration: #{args.name}
      # Created at: #{Time.now}
      # Use this file to make changes to the Schemafile

      # Example:
      # create_table "new_table", force: :cascade do |t|
      #   t.string "name", null: false
      #   t.timestamps
      # end
      #
      # add_column "existing_table", "new_column", :string, after: "existing_column"
      #
      # To apply this migration:
      # 1. Update the Schemafile with these changes
      # 2. Run `rake ridgepole:apply`
    RUBY

    puts "Created migration file #{path}"
  end

  private

  def config_file
    Rails.root.join("config/database.yml")
  end

  def schemafile
    Rails.root.join("db/Schemafile")
  end

  def ridgepole(options)
    command = "bundle exec ridgepole -c #{config_file} -E #{Rails.env} -f #{schemafile} #{options}"
    puts "[Command] #{command}"
    system(command, exception: true)
  end
end
