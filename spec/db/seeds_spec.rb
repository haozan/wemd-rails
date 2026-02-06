require 'rails_helper'

RSpec.describe "Database Seeds" do
  let(:seeds_file) { Rails.root.join('db/seeds.rb') }
  let(:marker_file) { Rails.root.join('tmp/seeds_executed') }

  # Get all non-admin model files
  let(:model_files) do
    Dir.glob(Rails.root.join('app/models/**/*.rb')).reject do |file|
      file.include?('/concerns/') ||
      file.include?('application_record.rb') ||
      File.basename(file).downcase.include?('admin')
    end
  end

  it "should have content and be executed in development" do
    # Pass if no non-admin models exist
    next if model_files.empty?

    # Step 1: Check seeds.rb has real content
    seeds_content = File.read(seeds_file)
    code_lines = seeds_content.lines.reject { |line| line.strip.empty? || line.strip.start_with?('#') }

    expect(code_lines).not_to be_empty,
      "Project has models, please add seed data in db/seeds.rb"

    # Step 2: Check seeds have been executed (development only)
    expect(File.exist?(marker_file)).to be_truthy,
      "db/seeds.rb has content but hasn't been executed. Run 'rails db:seed' to populate data."
  end
end
