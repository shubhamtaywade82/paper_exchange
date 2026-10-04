require 'simplecov'
SimpleCov.start 'rails' do
  skip '/spec/'
  skip '/config/'
  skip '/vendor/'
  group 'Services', 'app/services'
  group 'Models', 'app/models'
  group 'Controllers', 'app/controllers'
end
