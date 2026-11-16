---
name: mailer-observability
description: Instrument Rails email delivery with bounded, privacy-aware outcome telemetry and correlation context.
family: rails
---

# Mailer Observability

## Problem

Missing email is difficult to distinguish between enqueue, job, provider, recipient, and template failures without lifecycle telemetry.

## Use when

- diagnosing delivery failures;
- adding email telemetry;
- integrating observers/interceptors.

## Do not use when

- existing mail/job observability already answers the lifecycle questions and no contract changes.

## Repository inspection

Inspect Rails.error, ActiveSupport::Notifications, job telemetry, provider logs, correlation identifiers, and sensitive-data filtering.

## Implementation procedure

1. Define lifecycle stages: requested, enqueued, attempted, delivered, failed/unknown.
2. Capture mailer/action/provider and bounded identifiers.
3. Preserve request/job/correlation context where available.
4. Classify failures without logging sensitive payloads.
5. Add metrics for outcome, retry, latency, and fallback where useful.

## Example

```ruby
# config/initializers/mail_observability.rb
class DeliveryLogObserver
  def self.delivered_email(message)
    Rails.logger.info(
      event: "mail.delivered",
      mailer: message.header["X-Mailer-Action"]&.value, # set in ApplicationMailer
      message_id: message.message_id,
      recipient_domains: Array(message.to).map { _1.split("@").last }.uniq # no full addresses
    )
  end
end
ActionMailer::Base.register_observer(DeliveryLogObserver)

class ApplicationMailer < ActionMailer::Base
  after_action { headers["X-Mailer-Action"] = "#{self.class.name}##{action_name}" }
end

# Enqueue and job failures come from Active Job instrumentation:
ActiveSupport::Notifications.subscribe("enqueue.active_job") do |event|
  job = event.payload[:job]
  Rails.logger.info(event: "mail.enqueued", job_id: job.job_id) if job.is_a?(ActionMailer::MailDeliveryJob)
end
```

## Failure modes

- full recipient lists/body logging;
- high-cardinality message IDs as metric labels;
- observer with business side effects;
- telemetry emitted only on success;
- inability to distinguish unknown provider outcome.

## Testing

Assert telemetry fields/events and secret/sensitive-field filtering at the boundary that owns them.

## Review checklist

- [ ] lifecycle coverage
- [ ] bounded dimensions
- [ ] correlation
- [ ] privacy filtering
- [ ] unknown outcomes represented

## Related skills

rails-action-mailer, rails-observability, rails-incident-engineering, rails-active-job
