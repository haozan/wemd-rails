RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)

    begin
      Timeout.timeout(2) do
        Rails.application.load_seed
      end
    rescue Timeout::Error
      puts "\n⚠️  Seeds loading timeout (>2s), skipped."
    end
  end

  config.before(:each) do
    DatabaseCleaner.strategy = :transaction
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.append_after(:each) do
    DatabaseCleaner.clean
  end
end
