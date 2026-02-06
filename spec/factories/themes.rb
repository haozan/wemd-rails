FactoryBot.define do
  factory :theme do

    name { "MyString" }
    css { "MyText" }
    is_builtin { true }
    user_id { 1 }

  end
end
