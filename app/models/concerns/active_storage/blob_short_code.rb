# frozen_string_literal: true

# Concern for ActiveStorage::Blob to add short_code functionality
# Automatically generates unique short codes for blob URLs
#
# Usage:
#   blob.short_url => "/f/aB3xK9.png"
module ActiveStorage
  module BlobShortCode
    extend ActiveSupport::Concern

    included do
      before_create :generate_short_code
    end

    # Generate short URL path
    # @return [String] Short URL path like "/f/aB3xK9.png"
    def short_url
      "/f/#{short_code}#{File.extname(filename.to_s)}"
    end

    private

    def generate_short_code
      return if short_code.present?

      self.short_code = loop do
        code = SecureRandom.alphanumeric(8)
        # Skip database query during asset precompilation
        break code if ENV['SECRET_KEY_BASE_DUMMY'].present?
        break code unless ActiveStorage::Blob.exists?(short_code: code)
      end
    end
  end
end
