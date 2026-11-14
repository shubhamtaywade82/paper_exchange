# #8: streams every fill for one account as the trade commits, replacing the
# agent's 8-second polling of the orders endpoint.
#
# Subscribe with the identifier { "channel": "FillsChannel", "account_id": "ACC-1" }.
# The account defaults to "default", as it does for the REST API.
class FillsChannel < ApplicationCable::Channel
  def self.stream_name_for(account_id)
    "fills:#{account_id}"
  end

  def subscribed
    stream_from self.class.stream_name_for(account_id)
  end

  private

  def account_id
    params[:account_id].presence || "default"
  end
end
