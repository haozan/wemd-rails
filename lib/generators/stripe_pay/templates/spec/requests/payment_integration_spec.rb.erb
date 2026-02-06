require 'rails_helper'

RSpec.describe "Payment Integration", type: :request do
  describe "Payable models interface" do
    it "validates all payable models implement required methods" do
      Rails.application.eager_load!
      payable_models = ApplicationRecord.descendants.select do |model|
        assoc = model.reflect_on_association(:payment) || model.reflect_on_association(:payments)
        assoc&.options&.dig(:as) == :payable
      end

      has_subscription_mode = false

      payable_models.each do |model|
        factory = model.model_name.singular.to_sym
        instance = build(factory)

        # Validate required methods exist and return proper types
        expect(instance.customer_name).to be_a(String).and be_present
        expect(instance.customer_email).to match(URI::MailTo::EMAIL_REGEXP)
        expect(instance.payment_description).to be_a(String).and be_present
        expect(instance.stripe_mode).to be_in(['payment', 'subscription'])
        expect(instance.stripe_line_items).to be_an(Array).and be_present

        # Validate subscription mode has recurring
        if instance.stripe_mode == 'subscription'
          has_subscription_mode = true
          instance.stripe_line_items.each do |item|
            expect(item.dig(:price_data, :recurring)).to be_present,
              "#{model}.stripe_line_items missing :recurring (required for subscription mode)"
          end
        end
      end

      # Check CLACKY_TODO_SUBSCRIPTION if any model uses subscription mode
      if has_subscription_mode
        service_file = Rails.root.join('app/services/stripe_payment_service.rb')
        content = File.read(service_file) if File.exist?(service_file)
        if content&.include?('CLACKY_TODO_SUBSCRIPTION')
          fail "CLACKY_TODO_SUBSCRIPTION found in stripe_payment_service.rb - implement subscription webhooks!"
        end
      end
    end
  end

  describe "CLACKY_TODO validation" do
    it "validates that all payment CLACKY_TODOs have been resolved" do
      check_clacky_todos([
        'app/controllers/payments_controller.rb',
        'app/controllers/admin/payments_controller.rb',
        'app/services/stripe_payment_service.rb'
      ])
    end

    it "validates that required payment views have been created" do
      missing_views = []

      required_views = [
        'app/views/payments/success.html.erb'
      ]

      required_views.each do |view_path|
        unless File.exist?(Rails.root.join(view_path))
          missing_views << view_path
        end
      end

      if missing_views.any?
        error_message = "\n❌ Missing required payment views:\n\n"
        missing_views.each do |view|
          error_message += "📄 #{view}\n"
        end
        error_message += "\nThis view is required for Stripe payment success callback.\n"

        fail error_message
      end
    end

    it "validates that pay_payment_path is used correctly in controllers" do
      violations = []
      found_pay_payment_path = false

      # Check all controllers for redirect_to pay_payment_path(@payment)
      Dir.glob(Rails.root.join('app/controllers/**/*.rb')).each do |file_path|
        content = File.read(file_path)
        relative_path = file_path.sub(Rails.root.to_s + '/', '')

        # Skip payments controller itself
        next if relative_path.include?('payments_controller.rb')

        # Check if this controller redirects to pay_payment_path
        if content.match?(/redirect_to\s+pay_payment_path/)
          found_pay_payment_path = true

          # Check for passing wrong object to pay_payment_path (should be @payment, not @order/@subscription)
          if content.match?(/pay_payment_path\s*\(\s*@(?!payment\b)\w+/)
            violations << {
              file: relative_path,
              issue: "pay_payment_path must receive @payment object, not @order/@subscription/other objects"
            }
          end
        end
      end

      # Check if pay_payment_path is used at least once in controllers
      unless found_pay_payment_path
        fail "\n❌ No pay_payment_path redirect found in controllers!\n\n" \
             "You must redirect to pay_payment_path(@payment) in your controller to trigger Stripe payment.\n\n" \
             "Recommended usage in controller:\n" \
             "  @payment = @order.create_payment!(amount: @order.total, user: current_user)\n" \
             "  redirect_to pay_payment_path(@payment), data: { turbo_method: :post }\n"
      end

      # Check for incorrect object usage in controllers
      if violations.any?
        error_message = "\n❌ Found #{violations.length} payment path violation(s) in controllers:\n\n"

        violations.each do |v|
          error_message += "📄 #{v[:file]}\n"
          error_message += "   Issue: #{v[:issue]}\n\n"
        end

        error_message += "Correct usage:\n"
        error_message += "  redirect_to pay_payment_path(@payment), data: { turbo_method: :post }\n"
        error_message += "\nIncorrect usage:\n"
        error_message += "  redirect_to pay_payment_path(@order) ❌\n"
        error_message += "  redirect_to pay_payment_path(@subscription) ❌\n"

        fail error_message
      end
    end
  end
end
