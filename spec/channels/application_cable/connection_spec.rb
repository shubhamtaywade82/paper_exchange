require 'rails_helper'

# #8: the fills stream uses the same operator key as the REST API. The key check
# is a pure class method, so it is tested without opening a socket.
RSpec.describe ApplicationCable::Connection do
  describe '.authorized?' do
    it 'accepts the operator key' do
      expect(described_class.authorized?(ENV.fetch('PAPER_EXCHANGE_API_KEY'))).to be(true)
    end

    it 'rejects a wrong key, an empty key, and no key' do
      expect(described_class.authorized?('wrong-key')).to be(false)
      expect(described_class.authorized?('')).to be(false)
      expect(described_class.authorized?(nil)).to be(false)
    end

    it 'rejects every key when no operator key is configured' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('PAPER_EXCHANGE_API_KEY').and_return(nil)

      expect(described_class.authorized?('')).to be(false)
    end
  end
end
