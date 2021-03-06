require 'rails_helper'

describe MobileRecoveriesController do
  let(:phone_number) { '800-555-3455' }
  let(:user) { FactoryGirl.create(:user) }

  before :each do
    sign_in user
  end

  describe '#create' do
    before :each do
      post :create, profile: { mobile_number: phone_number }
      user.profile.reload
    end

    it 'sets the profile mobile number' do
      expect(user.profile.mobile_number).to match(phone_number)
    end
    it 'creates a mobile confirmation object' do
      confirmation = user.profile.mobile_confirmation
      expect(confirmation).to be
    end
    context 'mobile number is invalid' do
      let(:phone_number) { 'call me plz' }
      it 'validates phone number format' do
        expect(user.profile.mobile_number).to be_nil
        expect(flash[:error]).to be
      end
    end

  end

  describe "#update" do
    before :each do
      allow(SmsWrapper.instance).to receive(:send_message)
    end

    context 'with a valid token' do
      it 'confirms the mobile number' do
        confirmation = user.profile.create_mobile_confirmation
        confirmation.send(:generate_token)
        raw_token = confirmation.raw_token
        confirmation.save!

        patch :update, mobile_confirmation: { raw_token: raw_token }
        confirmation.reload

        expect(confirmation).to be_confirmed
      end
    end

    context 'with an invalid token' do
      it 'does not confirm the mobile number' do
        confirmation = user.profile.create_mobile_confirmation!
        patch :update, mobile_confirmation: { raw_token: 'foobar' }
        confirmation.reload

        expect(flash[:error]).to match(/Please check the number sent to your mobile and re-enter that code/)
        expect(confirmation).to_not be_confirmed
      end
    end
  end

  describe "#resend" do
    before :each do
      allow(SmsWrapper.instance).to receive(:send_message)
    end

    it 'sets a new token' do
      confirmation = user.profile.create_mobile_confirmation!
      old_token = confirmation.token

      get :resend
      confirmation.reload

      expect(confirmation.token).to_not match(old_token)
    end
  end

end
