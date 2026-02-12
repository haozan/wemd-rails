namespace :db do
  desc "Backup database to db/backups/"
  task backup: :environment do
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    backup_dir = Rails.root.join('db', 'backups')
    FileUtils.mkdir_p(backup_dir)
    backup_file = backup_dir.join("backup_#{timestamp}.sql")
    
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    
    case config[:adapter]
    when 'postgresql'
      cmd = "PGPASSWORD=#{config[:password]} pg_dump -h #{config[:host]} -U #{config[:username]} --no-owner --no-acl -f #{backup_file} #{config[:database]}"
      system(cmd)
      
      if $?.success?
        puts "✓ Backup created: #{backup_file}"
        puts "  Size: #{File.size(backup_file) / 1024}KB"
      else
        puts "✗ Backup failed"
      end
    else
      puts "✗ Unsupported adapter: #{config[:adapter]}"
    end
  end
  
  desc "Restore database from latest backup"
  task restore: :environment do
    backup_dir = Rails.root.join('db', 'backups')
    backups = Dir.glob(backup_dir.join('*.sql')).sort
    
    if backups.empty?
      puts "✗ No backups found in db/backups/"
      exit 1
    end
    
    latest_backup = backups.last
    puts "Found #{backups.count} backup(s)"
    puts "Latest backup: #{File.basename(latest_backup)} (#{File.size(latest_backup) / 1024}KB)"
    
    print "Restore from this backup? This will DROP and RECREATE the database! (yes/no): "
    response = STDIN.gets.chomp
    
    unless response.downcase == 'yes'
      puts "✗ Restore cancelled"
      exit 0
    end
    
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    
    case config[:adapter]
    when 'postgresql'
      puts "Dropping database..."
      Rake::Task['db:drop'].invoke
      
      puts "Creating database..."
      Rake::Task['db:create'].invoke
      
      puts "Restoring from backup..."
      cmd = "PGPASSWORD=#{config[:password]} psql -h #{config[:host]} -U #{config[:username]} -d #{config[:database]} -f #{latest_backup}"
      system(cmd)
      
      if $?.success?
        puts "✓ Database restored successfully"
      else
        puts "✗ Restore failed"
      end
    else
      puts "✗ Unsupported adapter: #{config[:adapter]}"
    end
  end
  
  desc "List all backups"
  task list_backups: :environment do
    backup_dir = Rails.root.join('db', 'backups')
    backups = Dir.glob(backup_dir.join('*.sql')).sort
    
    if backups.empty?
      puts "No backups found in db/backups/"
    else
      puts "Available backups:"
      backups.each do |backup|
        size_kb = File.size(backup) / 1024
        mtime = File.mtime(backup).strftime('%Y-%m-%d %H:%M:%S')
        puts "  #{File.basename(backup)} - #{size_kb}KB - #{mtime}"
      end
    end
  end
end
