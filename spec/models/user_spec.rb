require 'rails_helper'

RSpec.describe User, type: :model do
  it "validates presence of name" do
    user = build(:user)
    user.save!
    expect(user.email).to be_present
  end

  it 'accepts only supported WeChat typography profiles' do
    user = build(:user, wx_typography_profile: 'large_18')

    expect(user).not_to be_valid
    expect(user.errors[:wx_typography_profile]).to be_present
  end
end
