require_relative "config/application"
Rails.application.load_tasks

if Rake::Task.task_defined?(:test)
  Rake::Task[:test].clear
end

# Clear test:prepare to prevent asset builds during testing
if Rake::Task.task_defined?('test:prepare')
  Rake::Task['test:prepare'].clear
end

task 'test:prepare' do
  # Empty task - no asset building needed for tests
end

task :test do
  exec 'bundle exec rspec'
end
