class ApplicationMailer < ActionMailer::Base
  default from: "#{(Rails.application.config.x.appname.presence || 'ClackyAI')} <notifications@#{ENV["CLACKY_EMAIL_SMTP_DOMAIN"] || ENV.fetch("EMAIL_SMTP_DOMAIN", 'example.com')}>"
  layout "mailer"
end
