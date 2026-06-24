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
    # A valid public DNS hostname: dot-separated labels + a real TLD, only letters/
    # digits/hyphens. Rejects localhost, bare IPs, and malformed scraped hosts like
    # "ee,ifrc.org" (a comma) that URI.parse accepts but Telegram rejects with
    # BUTTON_URL_INVALID — which would otherwise fail the whole message.
    PUBLIC_HOST = /\A(?=.{1,253}\z)([a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}\z/i

    def self.single(job) = new.single(job)
    def self.single_buttons(notification) = new.single_buttons(notification)
    def self.url_buttons(job) = new.url_buttons(job)
    def self.refine_buttons(job, web_app_url) = new.refine_buttons(job, web_app_url)
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

    # Inline keyboard for a single match: any publicly-valid URL buttons (Telegram
    # rejects localhost/IP/non-http URLs) PLUS a 👍/👎 feedback row tied to this
    # specific notification via callback_data. The feedback row is always present.
    def single_buttons(notification)
      { inline_keyboard: url_rows(notification.job) + [feedback_row(notification)] }
    end

    # Keyboard after a 👍: URL buttons only (feedback row removed so it can't be
    # voted again). May be an empty keyboard (clears buttons) on localhost.
    def url_buttons(job)
      { inline_keyboard: url_rows(job) }
    end

    # Keyboard after a 👎: URL buttons plus a Web App button that opens the refine
    # Mini App at the signed URL.
    def refine_buttons(job, web_app_url)
      { inline_keyboard: url_rows(job) + [[refine_button(web_app_url)]] }
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

    # URL-button rows (View / Apply), only for publicly-valid URLs.
    def url_rows(job)
      rows = []
      rows << [{ text: I18n.t('telegram.buttons.view'), url: site_url(job) }] if buttonable?(site_url(job))
      rows << [{ text: I18n.t('telegram.buttons.apply'), url: apply_link(job) }] if buttonable?(apply_link(job))
      rows
    end

    def feedback_row(notification)
      [
        { text: I18n.t('telegram.feedback.good'), callback_data: "fb:up:#{notification.id}" },
        { text: I18n.t('telegram.feedback.bad'), callback_data: "fb:down:#{notification.id}" }
      ]
    end

    # Web App button opens the Mini App in Telegram's WebView; requires an https
    # URL (configured in BotFather). Falls back to a plain URL button otherwise.
    def refine_button(url)
      label = I18n.t('telegram.feedback.refine')
      buttonable?(url) ? { text: label, web_app: { url: } } : { text: label, url: }
    end

    # Telegram only accepts public http(s) URLs in inline-keyboard buttons (no
    # localhost/IP, no mailto:/tel:, no malformed hosts).
    def buttonable?(url)
      uri = URI.parse(url)
      uri.is_a?(URI::HTTP) && uri.host.to_s.match?(PUBLIC_HOST)
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
