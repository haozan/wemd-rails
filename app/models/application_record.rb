class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Helper: Generate full URL for ActiveStorage attachments
  def attachment_url(attachment)
    return nil unless attachment.attached?
    Rails.application.routes.url_helpers.rails_blob_url(attachment)
  end
end
