
require 'feature_helper'

describe 'OAuth' do
  let(:user) { FactoryGirl.create(:user, email: 'testy.mctesterson@gsa.gov') }

  scopes = 'profile.email profile.title profile.first_name ' \
  'profile.middle_name profile.last_name profile.phone_number profile.suffix ' \
  'profile.address profile.address2 profile.zip profile.gender ' \
  'profile.marital_status profile.is_parent profile.is_student ' \
  'profile.is_veteran profile.is_retired notifications'

  let(:client_app) do
    FactoryGirl.create(:application, name: 'Client App 1', scopes: scopes)
  end
  let(:client_app2) { FactoryGirl.create(:application, name: 'Client App 2') }
  let(:requested_scopes) { 'profile.email profile.last_name notifications' }

  # Set up an OAuth2::Client instance for HTTP calls that happen outside of the
  # Capybara context. More detail here:
  # https://github.com/doorkeeper-gem/doorkeeper/wiki/Testing-your-provider-with-OAuth2-gem
  let(:oauth_client) do
    OAuth2::Client.new(client_app.uid,
                       client_app.secret,
                       site: 'http://www.example.com') do |b|
      b.request :url_encoded
      b.adapter :rack, Rails.application
    end
  end

  let(:oauth_client2) do
    # Set up an OAuth2::Client instance for HTTP calls that happen outside of
    # the Capybara context.
    # More detail here: https://github.com/doorkeeper-gem/doorkeeper/wiki/Testing-your-provider-with-OAuth2-gem
    OAuth2::Client.new(client_app2.uid,
                       client_app2.secret,
                       site: 'http://www.example.com/2') do |b|
      b.request :url_encoded
      b.adapter :rack, Rails.application
    end
  end

  def visit_oauth_authorize_url(client, app, scopes)
    visit(client.auth_code.authorize_url(
      redirect_uri: app.redirect_uri,
      scope: scopes,
      state: 'state'
    ))
  end

  describe 'Authorizations' do
    let(:requested_scopes) do
      'profile.email profile.title profile.first_name profile.middle_name ' \
      'profile.last_name profile.phone_number profile.suffix profile.address ' \
      'profile.address2 profile.zip profile.gender profile.marital_status ' \
      'profile.is_parent profile.is_student profile.is_veteran ' \
      'profile.is_retired notifications'
    end

    let(:client_application_scopes2) do
      'profile.email profile.phone_number profile.zip profile.gender ' \
      'profile.is_parent profile.is_student profile.is_veteran notifications'
    end

    let(:requested_scopes2) do
      'profile.email profile.phone_number profile.zip profile.gender ' \
      'notifications'
    end

    let(:client_app2) do
      FactoryGirl.create(:application, name: 'Client App 2',
                                       scopes: client_application_scopes2)
    end

    before :each do
      @auths_page = OAuth2::AuthorizationsPage.new
    end

    context 'when not logged in' do
      before :each do
        @auths_page.load
      end

      scenario 'redirects to login page' do
        @sign_in_page = SignInPage.new
        expect(@sign_in_page).to be_displayed
      end
    end

    context 'when logged in' do
      before :each do
        login user
        @auth_page = OAuth2::AuthorizationPage.new
        @token_page = OAuth2::TokenPage.new
        visit_oauth_authorize_url(oauth_client, client_app, requested_scopes)
        expect(@auth_page).to be_displayed
        @auth_page.allow_button.click

        # Retrieve the code
        expect(@token_page).to be_displayed
        code = @token_page.code.text

        # Turn the code into a token
        token = oauth_client.auth_code.get_token(
          code, redirect_uri: client_app.redirect_uri
        )
        expect(token).to_not be_expired
        client_app.redirect_uri = 'http://localhost:3000'
        client_app.save!

        visit_oauth_authorize_url(oauth_client2, client_app2, requested_scopes2)
        expect(@auth_page).to be_displayed
        @auth_page.allow_button.click

        # Retrieve the code
        expect(@token_page).to be_displayed
        code = @token_page.code.text

        # Turn the code into a token
        token = oauth_client2.auth_code.get_token(
          code, redirect_uri: client_app2.redirect_uri
        )
        expect(token).to_not be_expired

        @auths_page.load
      end

      it 'displays the authorizations' do
        expect(@auths_page).to be_displayed
        expect(@auths_page.first_app.app_name).to have_content 'Client App 1'
        expect(@auths_page.second_app.app_name).to have_content 'Client App 2'
        expect(@auths_page.first_app.app_scopes.map(&:text)).to eq(
          ['Email Address', 'Title', 'First Name', 'Middle Name', 'Last Name',
           'Suffix', 'Home Address', 'Home Address (Line 2)', 'Zip Code',
           'Phone Number', 'Gender', 'Marital Status', 'Are you a Parent?',
           'Are you a Student?', 'Are you a Veteran?', 'Are you Retired?'])
        expect(@auths_page.first_app.app_scope_sections.map(&:text)).to eq(
          ['Identify you by your email address',
           'Address you by name',
           'Know where you live',
           'Know how to contact you by phone or text message',
           'Find out more about you',
           'Send you notifications via MyUSA'])
        expect(@auths_page.second_app.app_scopes.map(&:text)).to eq(
          ['Email Address', 'Zip Code', 'Phone Number', 'Gender'])
        expect(@auths_page.second_app.app_scope_sections.map(&:text)).to eq(
          ['Identify you by your email address',
           'Know where you live',
           'Know how to contact you by phone or text message',
           'Find out more about you',
           'Send you notifications via MyUSA'])
      end

      it 'revokes authorization to an application' do
        expect(@auths_page).to be_displayed
        expect(@auths_page.second_app.app_name).to have_content 'Client App 2'
        @auths_page.second_revoke_button.click
        expect(@auths_page).to be_displayed
        expect(@auths_page.first_app.app_name).to have_content 'Client App 1'
        expect(@auths_page).to_not have_content 'Client App 2'
      end
    end
  end

  describe 'applications' do 
    before :each do 
      login user
      @new_application_page = OAuth2::NewApplicationPage.new
      @auths_page = OAuth2::AuthorizationsPage.new
      @new_application_page.load
      @new_application_page.name.set 'testApp'
      @new_application_page.redirect_uri.set 'urn:ietf:wg:oauth:2.0:oob'
      @new_application_page.check('First Name')
      @new_application_page.submit.click
    end

    it "allows user to create app with image and get secret" do
      expect(@auths_page).to be_displayed
      expect(@auths_page.secret_key).to be_present
    end

    it "allows user to generate new api key" do
      app = Doorkeeper::Application.find_by_name('testApp')
      old_secret = app.secret
      @auths_page.new_api_key.click
      expect(@auths_page.secret_key).to_not match(old_secret)
    end

    it 'displays private status' do
      expect(@auths_page.first_developer_app.status).to eq('Private')
    end

    it 'allows a user to request public access' do
      @auths_page.first_developer_app.request_public.click
      expect(@auths_page.first_developer_app.status).to eq('Pending Approval')
    end

    it 'displays public status' do
      app = Doorkeeper::Application.find_by_name('testApp')
      app.public = true
      app.save
      @auths_page.load
      expect(@auths_page.first_developer_app.status).to eq('Public')
    end
  end
end
