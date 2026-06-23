# frozen_string_literal: true

module JobAlerts
  # Renders job matches into nicely-formatted Telegram HTML messages plus an inline
  # keyboard (tappable buttons). Telegram caps messages at 4096 chars, so digests
  # are bounded by MAX_DIGEST with an overflow note.
  class TelegramMessage
    MAX_DIGEST = 12
    SUMMARY_LENGTH = 220
    DIVIDER = '━━━━━━━━━━━━━━━'
    SITE_LOCALE = 'en'
    CLOSING_SOON_DAYS = 7

    def self.single(job) = new.single(job)
    def self.single_buttons(job) = new.single_buttons(job)
    def self.digest(jobs, frequency:) = new.digest(jobs, frequency:)

    # Body for a single match. The bold text detail link always works (incl.
    # localhost). When the site URL is public, #single_buttons additionally renders
    # a tappable button for an even stronger call-to-action.
    def single(job)
      [
        '🎯 <b>New match for your job alert!</b>',
        format_job(job),
        cta_links(job),
        '👉 <b>Tap “View job on Resume.et” for the full details</b>'
      ].compact.join("\n\n")
    end

    # Inline keyboard (URL buttons) for a single match — only for publicly-valid
    # URLs. Telegram rejects button URLs that are localhost/IP or non-http (mailto:),
    # so on those we fall back to the in-body text links and return nil here.
    def single_buttons(job)
      rows = []
      rows << [{ text: '🔎 View full details →', url: site_url(job) }] if buttonable?(site_url(job))
      rows << [{ text: '➡️ Apply now', url: apply_link(job) }] if buttonable?(apply_link(job))
      rows.empty? ? nil : { inline_keyboard: rows }
    end

    def digest(jobs, frequency:)
      shown = jobs.first(MAX_DIGEST)
      header = "🔔 <b>Your #{frequency} job digest</b>\n✨ #{pluralize(jobs.size, 'new match')} for you"
      body = shown.map { |job| "#{format_job(job)}\n\n#{cta_links(job)}" }.join("\n\n#{DIVIDER}\n\n")
      footer = jobs.size > MAX_DIGEST ? "\n\n#{DIVIDER}\n\n➕ <b>#{jobs.size - MAX_DIGEST}</b> more on Resume.et" : ''
      "#{header}\n\n#{body}#{footer}"
    end

    private

    def format_job(job)
      [headline(job), meta_block(job), summary_block(job)].compact.join("\n\n")
    end

    def headline(job)
      lines = ["💼 <b>#{esc(job.title)}</b>"]
      lines << "🏢 #{esc(job.company_name)}" if job.company_name.present?
      lines.join("\n")
    end

    # The at-a-glance facts, one per line so each emoji label lines up.
    def meta_block(job)
      lines = []
      lines << "📍 #{esc(location(job))}" if location(job).present?
      lines << "🕒 #{esc(employment_type(job))}" if employment_type(job).present?
      lines << "🎯 #{esc(job.experience_level)}" if job.experience_level.present?
      lines << "💰 #{esc(job.salary)}" if job.salary.present?
      lines << "🗓 Posted #{job.posted_on.to_fs(:long)}" if job.posted_on.present?
      lines << deadline_line(job) if job.deadline_on.present?
      lines.presence&.join("\n")
    end

    # Adds gentle urgency when the deadline is near to encourage a click.
    def deadline_line(job)
      days = (job.deadline_on - Date.current).to_i
      if days.between?(0, CLOSING_SOON_DAYS)
        "🔥 Closing soon — apply by #{job.deadline_on.to_fs(:long)}"
      else
        "⏳ Apply by #{job.deadline_on.to_fs(:long)}"
      end
    end

    def summary_block(job)
      summary = clean_summary(job.summary)
      return if summary.blank?

      "<blockquote>#{esc(summary)}</blockquote>"
    end

    # Text links for the digest (which has no per-job buttons).
    def cta_links(job)
      [
        %(🔎 <b><a href="#{esc(site_url(job))}">View job on Resume.et</a></b>),
        %(➡️ <a href="#{esc(apply_link(job))}">Apply directly</a>)
      ].join("\n")
    end

    # Telegram only accepts public http(s) URLs in inline-keyboard buttons (no
    # localhost/IP, no mailto:/tel:).
    def buttonable?(url)
      uri = URI.parse(url)
      uri.is_a?(URI::HTTP) && uri.host.to_s.include?('.') &&
        !uri.host.start_with?('localhost') && uri.host != '127.0.0.1'
    rescue URI::InvalidURIError
      false
    end

    # Link back to the job's detail page on the frontend site.
    def site_url(job)
      base = ENV.fetch('FRONTEND_URL', 'http://localhost:3001').delete_suffix('/')
      "#{base}/#{SITE_LOCALE}/jobs/#{job.id}"
    end

    def location(job)
      [job.location, ('🌐 Remote' if job.remote?)].compact.join(' · ')
    end

    def employment_type(job)
      job.employment_type.to_s.tr('_', ' ').strip.presence&.titleize
    end

    def apply_link(job)
      job.apply_url.presence || job.url
    end

    def clean_summary(text)
      return if text.blank?

      stripped = ActionController::Base.helpers.strip_tags(text).gsub(/\s+/, ' ').strip
      stripped.length > SUMMARY_LENGTH ? "#{stripped[0, SUMMARY_LENGTH].rstrip}…" : stripped
    end

    def pluralize(count, noun)
      "#{count} #{noun}#{'es' unless count == 1}"
    end

    def esc(text)
      ERB::Util.html_escape(text.to_s)
    end
  end
end
