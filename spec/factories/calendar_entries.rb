FactoryBot.define do
  factory :calendar_entry do

    association :user
    association :document
    calendar_date { Date.today }

  end
end
