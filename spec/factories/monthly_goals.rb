FactoryBot.define do
  factory :monthly_goal do

    association :user
    year { 1 }
    month { 1 }
    goal_content { "MyText" }

  end
end
