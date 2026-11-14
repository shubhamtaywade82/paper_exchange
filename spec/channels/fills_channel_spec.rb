require 'rails_helper'

# #8: a subscription streams the fills for the account it names.
RSpec.describe FillsChannel do
  it 'streams fills for the account named in the subscription' do
    subscribe(account_id: 'ACC-WS')

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from('fills:ACC-WS')
  end

  it 'falls back to the default account, as the REST API does' do
    subscribe

    expect(subscription).to have_stream_from('fills:default')
  end
end
