FactoryBot.define do
  factory :administrator do
    name { "admin" }
    password { "admin" }
    role { "admin" }
    
    trait :super_admin do
      role { "super_admin" }
    end
  end
end
