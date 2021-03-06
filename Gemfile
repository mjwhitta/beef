# BeEF's Gemfile

#
# Copyright (c) 2006-2019 Wade Alcorn - wade@bindshell.net
# Browser Exploitation Framework (BeEF) - http://beefproject.com
# See the file 'doc/COPYING' for copying permission
#

gem 'bigdecimal'
gem 'etc'
gem 'eventmachine'
gem 'thin'
gem 'sinatra', '~> 2.0'
gem 'rack', '~> 2.0'
gem 'rack-protection', '~> 2.0'
gem 'em-websocket' # WebSocket support
gem 'uglifier'
gem 'mime-types'
gem 'execjs'
gem 'ansi'
gem 'term-ansicolor', :require => 'term/ansicolor'
gem 'dm-core'
gem 'json'
gem 'data_objects'
gem 'rubyzip', '>= 1.2.2'
gem 'espeak-ruby', '>= 1.0.4' # Text-to-Voice
gem 'nokogiri', '>= 1.7'
gem 'rake'

# SQLite support
group :sqlite do
  gem 'dm-sqlite-adapter'
end

# PostgreSQL support
group :postgres do
  #gem dm-postgres-adapter
end

# MySQL support
group :mysql do
  #gem dm-mysql-adapter
end

# Geolocation support
group :geoip do
  gem 'maxmind-db'
end

gem 'parseconfig'
gem 'erubis'
gem 'dm-migrations'

# Metasploit Integration extension
group :ext_msf do
  gem 'msfrpc-client'
  gem 'xmlrpc'
end

# Notifications extension
group :ext_notifications do
  # Pushover
  gem 'rushover'
  # Slack
  gem 'slack-notifier'
  # Twitter
  gem 'twitter', '>= 5.0.0'
end

# DNS extension
group :ext_dns do
  gem 'rubydns', '~> 0.7.3'
end

# QRcode extension
group :ext_qrcode do
  gem 'qr4r'
end

# For running unit tests
group :test do
  if ENV['BEEF_TEST']
    gem 'test-unit'
    gem 'test-unit-full'
    gem 'rspec'
	gem 'rdoc'
    # curb gem requires curl libraries
    # sudo apt-get install libcurl4-openssl-dev
    gem 'curb'
    # selenium-webdriver 3.x is incompatible with Firefox version 48 and prior
    gem 'selenium'
    gem 'selenium-webdriver', '~> 2.53.4'
    # nokogirl is needed by capybara which may require one of the below commands
    # sudo apt-get install libxslt-dev libxml2-dev
    # sudo port install libxml2 libxslt
    gem 'capybara'
    # RESTful API tests/generic command module tests
    gem 'rest-client', '>= 2.0.1'
    gem 'byebug'
  end
end

source 'https://rubygems.org'
