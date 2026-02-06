module TestDataHelpers
  # Use existing data from database (e.g., from seeds) if available,
  # otherwise create new data using factory.
  # This helps test rendering with actual data without creating duplicate records.
  #
  # Usage:
  #   let(:user) { last_or_create(:user) }
  #   let(:admin) { last_or_create(:administrator) }
  def last_or_create(factory_name, **attrs)
    model_class = factory_name.to_s.classify.constantize
    model_class.last || create(factory_name, **attrs)
  end
end

RSpec.configure do |config|
  config.include TestDataHelpers, type: :request
  config.include TestDataHelpers, type: :feature
end
