namespace :db do
  desc "Export all data to YAML backup"
  task export: :environment do
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    backup_dir = Rails.root.join('db', 'backups')
    FileUtils.mkdir_p(backup_dir)
    backup_file = backup_dir.join("rails_backup_#{timestamp}.yml")
    
    data = {}
    
    # 导出所有表的数据
    ActiveRecord::Base.connection.tables.each do |table_name|
      next if table_name == 'schema_migrations' || table_name == 'ar_internal_metadata'
      
      model_name = table_name.singularize.camelize
      begin
        model = model_name.constantize
        data[table_name] = model.all.map(&:attributes)
        puts "✓ Exported #{data[table_name].count} records from #{table_name}"
      rescue NameError
        puts "⚠ Skipping #{table_name} (no model found)"
      end
    end
    
    File.write(backup_file, data.to_yaml)
    puts "\n✓ Backup created: #{backup_file}"
    puts "  Size: #{File.size(backup_file) / 1024}KB"
    puts "  Tables: #{data.keys.count}"
    puts "  Total records: #{data.values.sum(&:count)}"
  end
  
  desc "Import data from latest YAML backup"
  task import: :environment do
    backup_dir = Rails.root.join('db', 'backups')
    backups = Dir.glob(backup_dir.join('rails_backup_*.yml')).sort
    
    if backups.empty?
      puts "✗ No YAML backups found in db/backups/"
      puts "Run: rails db:export"
      exit 1
    end
    
    latest_backup = backups.last
    puts "Found #{backups.count} backup(s)"
    puts "Latest: #{File.basename(latest_backup)} (#{File.size(latest_backup) / 1024}KB)"
    
    print "\nRestore from this backup? This will CLEAR all existing data! (yes/no): "
    response = STDIN.gets.chomp
    
    unless response.downcase == 'yes'
      puts "✗ Import cancelled"
      exit 0
    end
    
    puts "\nLoading backup data..."
    data = YAML.load_file(latest_backup)
    
    ActiveRecord::Base.transaction do
      data.each do |table_name, records|
        model_name = table_name.singularize.camelize
        begin
          model = model_name.constantize
          
          puts "Clearing #{table_name}..."
          model.delete_all
          
          puts "Importing #{records.count} records to #{table_name}..."
          records.each do |attrs|
            model.create!(attrs)
          end
          
          puts "✓ Imported #{records.count} records to #{table_name}"
        rescue NameError
          puts "⚠ Skipping #{table_name} (no model found)"
        rescue => e
          puts "✗ Error importing #{table_name}: #{e.message}"
          raise
        end
      end
    end
    
    puts "\n✓ Database restored successfully"
  end
end
