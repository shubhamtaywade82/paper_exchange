require "rails_helper"

RSpec.describe AccountLeases do
  let(:account_id) { "ACC-LEASE-SVC" }

  def acquire(holder, label: holder, ttl: 30)
    described_class.acquire!(account_id: account_id, holder_id: holder, label: label, ttl_seconds: ttl)
  end

  def lease_row
    AccountLease.find_by!(venue: described_class::VENUE, account_id: account_id)
  end

  # Ages the lease past its expiry on the database clock, the only clock a lease answers to. Relative to now() because
  # a transaction's now() is its start time, so a Ruby-clock timestamp could still sit in the live window.
  def expire_now!
    AccountLease.where(venue: described_class::VENUE, account_id: account_id).update_all("expires_at = now() - interval '1 second'")
  end

  def live?(lease)
    AccountLease.where(id: lease.id).where("expires_at > now()").exists?
  end

  describe ".ttl_seconds" do
    it "defaults when the value is absent or blank" do
      expect(described_class.ttl_seconds(nil)).to eq(30)
      expect(described_class.ttl_seconds("  ")).to eq(30)
    end

    it "accepts whole numbers from 10 to 600 inclusive" do
      expect(described_class.ttl_seconds("10")).to eq(10)
      expect(described_class.ttl_seconds(600)).to eq(600)
    end

    it "refuses out-of-range values rather than clamping them" do
      [ 9, 601, 0, -5 ].each { |raw| expect(described_class.ttl_seconds(raw)).to be_nil }
    end

    it "refuses values that are not whole numbers" do
      [ "12.5", "abc", "1e2" ].each { |raw| expect(described_class.ttl_seconds(raw)).to be_nil }
    end
  end

  describe ".acquire!" do
    it "grants a free account with fence 1 and a live expiry" do
      lease = acquire("agent-a")
      expect([ lease.holder_id, lease.fence ]).to eq([ "agent-a", 1 ])
      expect(live?(lease)).to be(true)
    end

    it "refuses a second holder while the lease is live, naming the first holder and when it lapses" do
      acquire("agent-a", label: "Agent A")
      error = nil
      expect { acquire("agent-b") }.to raise_error(AccountLeases::Held) { |e| error = e }
      expect(error.holder_label).to eq("Agent A")
      expect(error.expires_at).to be_present
    end

    it "renews the same holder's live lease without advancing the fence" do
      first = acquire("agent-a")
      second = acquire("agent-a")
      expect(second.fence).to eq(first.fence)
      expect(second.expires_at).to be >= first.expires_at
    end

    it "takes over an expired lease, advancing the fence so the old holder is fenced out" do
      stale = acquire("agent-a")
      expire_now!
      taken = acquire("agent-b")
      expect([ taken.holder_id, taken.fence ]).to eq([ "agent-b", 2 ])
      expect(stale.fence).to eq(1)
    end

    it "gives an expired holder a new fence when it asks again after its own lease lapsed" do
      acquire("agent-a")
      expire_now!
      expect(acquire("agent-a").fence).to eq(2)
    end

    it "lets the next holder take a released lease at once" do
      lease = acquire("agent-a")
      described_class.release!(account_id: account_id, holder_id: "agent-a", fence: lease.fence)
      expect(acquire("agent-b").fence).to eq(2)
    end
  end

  describe ".heartbeat!" do
    it "extends the live lease under the presented fence without changing it" do
      lease = acquire("agent-a")
      renewed = described_class.heartbeat!(account_id: account_id, holder_id: "agent-a", fence: lease.fence, ttl_seconds: 600)
      expect([ renewed.holder_id, renewed.fence ]).to eq([ "agent-a", lease.fence ])
      expect(renewed.expires_at).to be > lease.expires_at
    end

    it "raises Lost for an expired lease, even before anyone takes it over" do
      lease = acquire("agent-a")
      expire_now!
      expect {
        described_class.heartbeat!(account_id: account_id, holder_id: "agent-a", fence: lease.fence, ttl_seconds: 30)
      }.to raise_error(AccountLeases::Lost)
    end

    it "raises Lost for a fence that a takeover has superseded" do
      stale = acquire("agent-a")
      expire_now!
      acquire("agent-b")
      expect {
        described_class.heartbeat!(account_id: account_id, holder_id: "agent-a", fence: stale.fence, ttl_seconds: 30)
      }.to raise_error(AccountLeases::Lost)
    end

    it "raises Required when the holder or the fence is absent" do
      acquire("agent-a")
      expect {
        described_class.heartbeat!(account_id: account_id, holder_id: nil, fence: nil, ttl_seconds: 30)
      }.to raise_error(AccountLeases::Required)
    end
  end

  describe ".release!" do
    it "frees the account for the next holder and stamps the release" do
      lease = acquire("agent-a")
      expect(described_class.release!(account_id: account_id, holder_id: "agent-a", fence: lease.fence)).to be(true)
      expect(lease_row.holder_id).to be_nil
      expect(lease_row.released_at).to be_present
    end

    it "changes nothing and reports false under a superseded fence" do
      stale = acquire("agent-a")
      expire_now!
      acquire("agent-b")
      expect(described_class.release!(account_id: account_id, holder_id: "agent-a", fence: stale.fence)).to be(false)
      expect(lease_row.holder_id).to eq("agent-b")
    end

    it "reports false on a second release" do
      lease = acquire("agent-a")
      described_class.release!(account_id: account_id, holder_id: "agent-a", fence: lease.fence)
      expect(described_class.release!(account_id: account_id, holder_id: "agent-a", fence: lease.fence)).to be(false)
    end

    it "raises Required when the holder is absent" do
      expect {
        described_class.release!(account_id: account_id, holder_id: "", fence: "1")
      }.to raise_error(AccountLeases::Required)
    end
  end

  describe ".assert_writable!" do
    it "returns the live row for the holder under the current fence" do
      lease = acquire("agent-a")
      row = described_class.assert_writable!(account_id: account_id, holder_id: "agent-a", fence: lease.fence.to_s)
      expect(row.holder_id).to eq("agent-a")
    end

    it "refuses an account that has never been leased" do
      expect {
        described_class.assert_writable!(account_id: account_id, holder_id: "agent-a", fence: "1")
      }.to raise_error(AccountLeases::Lost)
    end

    it "refuses a different holder presenting the live fence" do
      lease = acquire("agent-a")
      expect {
        described_class.assert_writable!(account_id: account_id, holder_id: "agent-b", fence: lease.fence.to_s)
      }.to raise_error(AccountLeases::Lost)
    end

    it "refuses a fence that a takeover has superseded" do
      stale = acquire("agent-a")
      expire_now!
      acquire("agent-b")
      expect {
        described_class.assert_writable!(account_id: account_id, holder_id: "agent-a", fence: stale.fence.to_s)
      }.to raise_error(AccountLeases::Lost)
    end

    it "refuses the holder once its lease has expired" do
      lease = acquire("agent-a")
      expire_now!
      expect {
        described_class.assert_writable!(account_id: account_id, holder_id: "agent-a", fence: lease.fence.to_s)
      }.to raise_error(AccountLeases::Lost)
    end

    it "refuses the holder of a released lease" do
      lease = acquire("agent-a")
      described_class.release!(account_id: account_id, holder_id: "agent-a", fence: lease.fence)
      expect {
        described_class.assert_writable!(account_id: account_id, holder_id: "agent-a", fence: lease.fence.to_s)
      }.to raise_error(AccountLeases::Lost)
    end

    it "requires both the holder and the fence" do
      acquire("agent-a")
      expect {
        described_class.assert_writable!(account_id: account_id, holder_id: nil, fence: "1")
      }.to raise_error(AccountLeases::Required)
      expect {
        described_class.assert_writable!(account_id: account_id, holder_id: "agent-a", fence: nil)
      }.to raise_error(AccountLeases::Required)
    end

    it "refuses a fence that is not a whole number" do
      acquire("agent-a")
      expect {
        described_class.assert_writable!(account_id: account_id, holder_id: "agent-a", fence: "one")
      }.to raise_error(AccountLeases::Lost, /whole number/)
    end
  end

  describe "under concurrent acquisition" do
    # Real commits, so the racing connections contend on the same row. The rows this group creates are removed afterwards.
    self.use_transactional_tests = false

    after { AccountLease.where(venue: described_class::VENUE, account_id: account_id).delete_all }

    # Starts every acquirer at the same moment, each on its own pooled connection, and returns every outcome.
    def race_acquire(holders)
      gate = Queue.new
      threads = holders.map do |holder|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            gate.pop
            begin
              [ :granted, holder, described_class.acquire!(account_id: account_id, holder_id: holder, label: holder, ttl_seconds: 30) ]
            rescue AccountLeases::Held => e
              [ :held, holder, e ]
            end
          end
        end
      end
      holders.size.times { gate << :go }
      threads.map(&:value)
    end

    it "lets exactly one of several simultaneous acquirers win a free account" do
      outcomes = race_acquire(%w[agent-a agent-b agent-c agent-d])
      winners = outcomes.select { |kind, *| kind == :granted }
      expect(winners.size).to eq(1)
      expect(outcomes.count { |kind, *| kind == :held }).to eq(3)
      expect([ lease_row.holder_id, lease_row.fence ]).to eq([ winners.first[1], 1 ])
    end

    it "lets exactly one of several simultaneous acquirers take over an expired lease, advancing the fence once" do
      acquire("agent-old")
      expire_now!
      outcomes = race_acquire(%w[agent-a agent-b agent-c agent-d])
      winners = outcomes.select { |kind, *| kind == :granted }
      expect(winners.size).to eq(1)
      expect([ lease_row.holder_id, lease_row.fence ]).to eq([ winners.first[1], 2 ])
    end

    it "refuses a locked lease check outside a transaction, where the lock would be released at once" do
      acquire("agent-a")
      expect {
        described_class.assert_writable!(account_id: account_id, holder_id: "agent-a", fence: lease_row.fence.to_s, lock: true)
      }.to raise_error(ArgumentError, /transaction/)
    end

    # A fenced write checks its lease and writes in one transaction, holding the row FOR SHARE. The lease runs out while the
    # write is in flight, yet a takeover must wait for that write to commit before it is granted.
    it "holds a takeover back until the fenced write that checked the lease has committed" do
      lease = acquire("agent-a")
      AccountLease.where(venue: described_class::VENUE, account_id: account_id).update_all("expires_at = now() + interval '1 second'")
      locked = Queue.new
      writer = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          AccountLease.transaction do
            described_class.assert_writable!(account_id: account_id, holder_id: "agent-a", fence: lease.fence.to_s, lock: true)
            locked << Process.clock_gettime(Process::CLOCK_MONOTONIC)
            sleep 2
          end
        end
      rescue StandardError => e
        locked << e
        raise
      end

      locked_at = locked.pop
      raise locked_at if locked_at.is_a?(Exception)

      sleep 1.5 # the lease has run out; only the in-flight write stands between a takeover and the account
      taken = described_class.acquire!(account_id: account_id, holder_id: "agent-b", label: "agent-b", ttl_seconds: 30)
      granted_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      writer.join

      expect(taken.fence).to eq(2)
      expect(granted_at - locked_at).to be >= 2
    end
  end
end
