# frozen_string_literal: true

module ApplicationHelper
  # Generate short URL for ActiveStorage blob
  # @param blob [ActiveStorage::Blob]
  # @return [String] Short URL path like "/f/aB3xK9.png"
  #
  # Usage in views:
  #   <%= image_tag blob_short_url(article.cover_image) %>
  #   <%= link_to 'Download', blob_short_url(file) %>
  def blob_short_url(blob)
    return nil unless blob.is_a?(ActiveStorage::Blob)
    
    blob.short_url
  end

  # Generate short URL for ActiveStorage attachment
  # @param attachment [ActiveStorage::Attached::One, ActiveStorage::Attachment]
  # @return [String, nil] Short URL path or nil if no attachment
  #
  # Usage in views:
  #   <%= image_tag attachment_short_url(user.avatar) %>
  def attachment_short_url(attachment)
    blob = case attachment
           when ActiveStorage::Attached::One
             attachment.blob if attachment.attached?
           when ActiveStorage::Attachment
             attachment.blob
           else
             nil
           end
    
    blob_short_url(blob) if blob
  end
end
