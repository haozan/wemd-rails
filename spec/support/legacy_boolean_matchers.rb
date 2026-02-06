# spec/support/legacy_boolean_matchers.rb
module LegacyBooleanMatchers
  extend RSpec::Matchers::DSL

  matcher :be_true do
    match { |actual| actual.equal?(true) }

    failure_message do |actual|
      "expected true, got #{actual.inspect} (#{actual.class})"
    end

    failure_message_when_negated do |_actual|
      "expected not to be true"
    end

    description { "be true (legacy matcher)" }
  end

  matcher :be_false do
    match { |actual| actual.equal?(false) }

    failure_message do |actual|
      "expected false, got #{actual.inspect} (#{actual.class})"
    end

    failure_message_when_negated do |_actual|
      "expected not to be false"
    end

    description { "be false (legacy matcher)" }
  end
end

RSpec.configure do |config|
  config.include LegacyBooleanMatchers
end
