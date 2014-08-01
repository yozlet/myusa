default_run_options[:pty] = true
ssh_options[:forward_agent] = true
ssh_options[:auth_methods] = ['publickey']

set :rails_env, :staging
set :ip, ENV['MYUSA_STAGING'] || 'staging.myusa.gsa.io'
set :port, 22
set :deployer, 'ubuntu'
set :user, 'ubuntu'

#
# Server Role Definitions
#
role :app, ip
role :web, ip
role :db, ip, primary: true
