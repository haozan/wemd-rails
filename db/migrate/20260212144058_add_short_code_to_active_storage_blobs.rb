class AddShortCodeToActiveStorageBlobs < ActiveRecord::Migration[7.2]
  def change
    add_column :active_storage_blobs, :short_code, :string
    add_index :active_storage_blobs, :short_code, unique: true

    # Generate short codes for existing blobs
    reversible do |dir|
      dir.up do
        ActiveStorage::Blob.find_each do |blob|
          blob.update_column(:short_code, generate_short_code)
        end
      end
    end
  end

  private

  def generate_short_code
    loop do
      code = SecureRandom.alphanumeric(8)
      break code unless ActiveStorage::Blob.exists?(short_code: code)
    end
  end
end
