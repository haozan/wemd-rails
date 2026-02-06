require 'rails_helper'

RSpec.describe User, type: :model do
  it "validates presence of name" do
    user = build(:user)
    user.save!
    expect(user.email).to be_present
  end
end
