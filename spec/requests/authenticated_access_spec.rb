require 'rails_helper'

RSpec.describe "Authenticated Access", type: :request do
  let(:user) { create(:user) }
  let(:navbar_file) { 'app/views/shared/_navbar.html.erb' }

  describe "Page access" do
    before { sign_in_as(user) }

    it "allows access to root path" do
      get root_path
      expect(response).to be_success_or_under_development
    end

    it "allows access to profile page" do
      get profile_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "Authentication flow" do
    it "signs up successfully and redirects to root" do
      post sign_up_path, params: {
        user: {
          name: 'New User',
          email: 'newuser@example.com',
          password: 'password123',
          password_confirmation: 'password123'
        }
      }

      expect(response).to redirect_to(root_path)
    end

    it "signs in successfully and redirects to root" do
      post sign_in_path, params: {
        user: {
          email: user.email,
          password: user.password
        }
      }

      expect(response).to redirect_to(root_path)
    end
  end

  describe "Authentication pages" do
    it "renders login page" do
      get sign_in_path
      expect(response).to be_success_with_view_check
    end

    it "renders signup page" do
      get sign_up_path
      expect(response).to be_success_with_view_check
    end
  end

  describe "Navbar customization" do
    it "validates navbar component TODOs are resolved" do
      user_dropdown_file = 'app/views/shared/_user_dropdown.html.erb'
      nav_links_file = 'app/views/shared/_nav_links.html.erb'

      # Check CLACKY_TODOs are resolved in all navbar components
      check_clacky_todos([navbar_file, user_dropdown_file, nav_links_file])
    end

    it "validates nav_links does not contain current_user checks or placeholder links" do
      nav_links_file = 'app/views/shared/_nav_links.html.erb'
      nav_links_path = Rails.root.join(nav_links_file)

      # Nav links file must exist
      expect(File.exist?(nav_links_path)).to be_truthy,
        "Nav links partial must exist at #{nav_links_path}"

      content = File.read(nav_links_path)

      # Check 1: nav_links should NOT contain 'current_user' or 'Current.user'
      has_current_user = content.include?('current_user') || content.include?('Current.user')
      expect(has_current_user).to be_falsey,
        "nav_links.html.erb should NOT contain 'current_user' or 'Current.user' checks. " \
        "Nav links are PUBLIC navigation links visible to ALL users (logged in or not). " \
        "For user-specific content, use user_dropdown partial instead."

      # Check 2: nav_links should NOT contain placeholder or anchor links
      doc = Nokogiri::HTML::DocumentFragment.parse(content)
      bad_links = doc.css('a[href^="#"], a[href^="javascript:"]')

      expect(bad_links).to be_empty,
        "Found #{bad_links.size} placeholder/anchor link(s) in nav_links. Replace them with real routes:\n" \
        "  - Static pages: create new page with controller/view/route\n" \
        "  - Functional links: use existing route helpers"
    end
  end
end
