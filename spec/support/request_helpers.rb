require 'spec_helper'
include Warden::Test::Helpers

def create_confirmed_user_with_profile(args={})
  profile = {
    email: 'joe@citizen.org',
    first_name: 'Joe',
    last_name: 'Citizen',
    is_student: true
  }.merge(args)

  User.create! do |user|
    user.email = profile.delete(:email)
    user.profile = user.build_profile(profile)
  end
end

def login(user)
  login_as user, scope: :user
end
