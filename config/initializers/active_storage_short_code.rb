# frozen_string_literal: true

# Patch ActiveStorage::Blob to include short_code functionality
Rails.application.config.to_prepare do
  ActiveStorage::Blob.include ActiveStorage::BlobShortCode
end
