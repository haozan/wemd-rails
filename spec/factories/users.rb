FactoryBot.define do
  factory :user do
    name { Faker::Name.name }
    email { Faker::Internet.email }
    password { "password123" }
    password_confirmation { "password123" }
    verified { true }

    trait :unverified do
      verified { false }
    end
  end
end
