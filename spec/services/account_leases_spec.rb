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

  describe ".status" do
    it "is nil for an account that was never leased" do
      expect(described_class.status(account_id: account_id)).to be_nil
    end

    it "reports a live lease as live, with its holder and fence" do
      lease = acquire("agent-a", label: "Agent A")
      status = described_class.status(account_id: account_id)
      expect(status[:live]).to be(true)
      expect([ status[:lease].holder_label, status[:lease].fence ]).to eq([ "Agent A", lease.fence ])
    end

    it "reports an expired lease as not live, though it still names its holder" do
      acquire("agent-a")
      expire_now!
      status = described_class.status(account_id: account_id)
      expect([ status[:live], status[:lease].holder_id ]).to eq([ false, "agent-a" ])
    end

    it "reports a released lease as not live, with no holder" do
      lease = acquire("agent-a")
      described_class.release!(account_id: account_id, holder_id: "agent-a", fence: lease.fence)
      status = described_class.status(account_id: account_id)
      expect([ status[:live], status[:lease].holder_id ]).to eq([ false, nil ])
    end
  end

  describe ".force_release!" do
    before { create(:account, account_id: account_id) }

    def force!(**overrides)
      described_class.force_release!(account_id: account_id, reason: "holder wedged", operator: "ops@host", **overrides)
    end

    def audit_events
      RiskEvent.where(account_id: account_id, event_type: "LEASE_FORCE_RELEASED")
    end

    it "releases a live lease at once, keeps its fence, and audits who was evicted and why" do
      lease = acquire("agent-a", label: "Agent A")
      force!(reason: "pid 4123 wedged")
      expect(lease_row.holder_id).to be_nil
      expect(lease_row.released_at).to be_present
      expect(lease_row.fence).to eq(lease.fence)
      expect(audit_events.sole.details).to include(
        "reason" => "pid 4123 wedged", "operator" => "ops@host", "released_holder_id" => "agent-a",
        "released_holder_label" => "Agent A", "released_fence" => lease.fence
      )
    end

    it "refuses the evicted holder's writes and heartbeats from the moment it commits" do
      lease = acquire("agent-a")
      force!
      expect {
        described_class.assert_writable!(account_id: account_id, holder_id: "agent-a", fence: lease.fence.to_s)
      }.to raise_error(AccountLeases::Lost)
      expect {
        described_class.heartbeat!(account_id: account_id, holder_id: "agent-a", fence: lease.fence, ttl_seconds: 30)
      }.to raise_error(AccountLeases::Lost)
    end

    it "lets the next holder in at a higher fence, so the evicted fence is never presentable again" do
      evicted = acquire("agent-a")
      force!
      taken = acquire("agent-b")
      expect([ taken.holder_id, taken.fence ]).to eq([ "agent-b", evicted.fence + 1 ])
      expect {
        described_class.assert_writable!(account_id: account_id, holder_id: "agent-a", fence: evicted.fence.to_s)
      }.to raise_error(AccountLeases::Lost)
    end

    it "returns the audit event it wrote" do
      acquire("agent-a")
      expect(force!).to eq(audit_events.sole)
    end

    it "refuses a blank reason or operator, and changes nothing" do
      acquire("agent-a")
      expect { force!(reason: "  ") }.to raise_error(ArgumentError, /reason/)
      expect { force!(operator: "") }.to raise_error(ArgumentError, /operator/)
      expect([ lease_row.holder_id, audit_events.count ]).to eq([ "agent-a", 0 ])
    end

    it "raises NotHeld for an account that was never leased, and audits nothing" do
      expect { force! }.to raise_error(AccountLeases::NotHeld)
      expect(audit_events.count).to eq(0)
    end

    it "raises NotHeld for an expired lease, which the next acquire takes without a force" do
      acquire("agent-a")
      expire_now!
      expect { force! }.to raise_error(AccountLeases::NotHeld)
      expect(audit_events.count).to eq(0)
    end

    it "raises NotHeld for a released lease, so a repeated force cannot audit twice" do
      lease = acquire("agent-a")
      described_class.release!(account_id: account_id, holder_id: "agent-a", fence: lease.fence)
      expect { force! }.to raise_error(AccountLeases::NotHeld)
      expect(audit_events.count).to eq(0)
    end

    it "refuses to evict a lease on an account with no row, since the eviction could not be audited" do
      acquire("agent-a")
      Account.where(account_id: account_id).delete_all
      expect { force! }.to raise_error(AccountLeases::UnknownAccount)
      expect([ lease_row.holder_id, audit_events.count ]).to eq([ "agent-a", 0 ])
    end

    it "rejects a lock timeout that is not positive" do
      acquire("agent-a")
      expect { force!(lock_timeout: 0) }.to raise_error(ArgumentError, /lock_timeout/)
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

  describe "forcing a release under an in-flight write" do
    # Real commits, so the forced release contends with a genuine lock holder. The rows this group creates are removed afterwards.
    self.use_transactional_tests = false

    before { create(:account, account_id: account_id) }

    after do
      AccountLease.where(venue: described_class::VENUE, account_id: account_id).delete_all
      RiskEvent.where(account_id: account_id).delete_all
      Account.where(account_id: account_id).delete_all
    end

    # Holds the lease row FOR SHARE, as a fenced write does, for `seconds`. Returns the thread and the moment the lock was taken.
    def hold_fenced_write(lease, seconds)
      locked = Queue.new
      writer = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          AccountLease.transaction do
            described_class.assert_writable!(account_id: account_id, holder_id: lease.holder_id, fence: lease.fence.to_s, lock: true)
            locked << Process.clock_gettime(Process::CLOCK_MONOTONIC)
            sleep seconds
          end
        end
      rescue StandardError => e
        locked << e
        raise
      end
      locked_at = locked.pop
      raise locked_at if locked_at.is_a?(Exception)

      [ writer, locked_at ]
    end

    it "waits for a fenced write already in flight to commit, then releases" do
      lease = acquire("agent-a")
      writer, locked_at = hold_fenced_write(lease, 2)
      sleep 0.5 # the release must queue behind the write's lock, not run ahead of it
      described_class.force_release!(account_id: account_id, reason: "wedged", operator: "ops@host")
      released_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      writer.join

      expect(released_at - locked_at).to be >= 2
      expect([ lease_row.holder_id, RiskEvent.where(account_id: account_id).count ]).to eq([ nil, 1 ])
    end

    it "gives up at the lock timeout when a write still holds the row, releasing nothing" do
      lease = acquire("agent-a")
      writer, _locked_at = hold_fenced_write(lease, 2)
      error = nil
      begin
        described_class.force_release!(account_id: account_id, reason: "wedged", operator: "ops@host", lock_timeout: 0.3)
      rescue ActiveRecord::LockWaitTimeout => e
        error = e
      end
      writer.join

      expect(error).to be_a(ActiveRecord::LockWaitTimeout)
      expect([ lease_row.holder_id, RiskEvent.where(account_id: account_id).count ]).to eq([ "agent-a", 0 ])
    end
  end
end
