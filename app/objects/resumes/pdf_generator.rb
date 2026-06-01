# frozen_string_literal: true

module Resumes
  class PdfGenerator
    require 'prawn'

    MARGIN = 48

    def initialize(resume)
      @resume = resume
      @profile = resume.profile
    end

    def render
      Prawn::Document.new(page_size: 'A4', margin: MARGIN) do |pdf|
        render_header(pdf)
        render_summary(pdf)
        render_experiences(pdf)
        render_education(pdf)
        render_certifications(pdf)
        render_skills(pdf)
        render_projects(pdf)
        render_additional_sections(pdf)
      end.render
    end

    private

    def render_header(pdf)
      name = @profile&.full_name.presence || @resume.title
      pdf.text name, size: 22, style: :bold
      pdf.move_down 6

      contact = [
        @resume.user.email,
        @profile&.phone,
        location_label,
        @profile&.linkedin_url,
        @profile&.github_url,
        @profile&.portfolio_url
      ].compact

      pdf.text contact.join('  |  '), size: 10, color: '444444' if contact.any?
      pdf.move_down 16
      pdf.stroke_horizontal_rule
      pdf.move_down 16
    end

    def render_summary(pdf)
      return if @profile&.career_summary.blank?

      section_title(pdf, 'Professional Summary')
      summary_lines = [
        [@profile.job_title, @profile.industry].compact.join(' — '),
        @profile.years_of_experience ? "#{@profile.years_of_experience} years of experience" : nil,
        @profile.career_summary
      ].compact

      pdf.text summary_lines.join("\n"), size: 10, leading: 4
      pdf.move_down 12
    end

    def render_experiences(pdf)
      return if @resume.experiences.empty?

      section_title(pdf, 'Work Experience')
      @resume.experiences.order(:position).each do |exp|
        pdf.text exp.job_title, size: 11, style: :bold
        pdf.text [exp.company, exp.location].compact.join(' — '), size: 10
        pdf.text format_date_range(exp.start_date, exp.end_date, exp.current), size: 9, color: '666666'
        bullet_list(pdf, exp.responsibilities)
        bullet_list(pdf, exp.achievements, prefix: 'Achievement: ')
        tech = Array(exp.technologies).join(', ')
        pdf.text "Technologies: #{tech}", size: 9 if tech.present?
        pdf.move_down 8
      end
    end

    def render_education(pdf)
      return if @resume.educations.empty?

      section_title(pdf, 'Education')
      @resume.educations.order(:position).each do |edu|
        pdf.text edu.institution, size: 11, style: :bold
        line = [edu.degree, edu.field_of_study].compact.join(', ')
        pdf.text line, size: 10 if line.present?
        years = [edu.start_year, edu.end_year].compact.join(' — ')
        pdf.text years, size: 9, color: '666666' if years.present?
        extras = [edu.gpa.present? ? "GPA: #{edu.gpa}" : nil, edu.honors].compact.join(' | ')
        pdf.text extras, size: 9 if extras.present?
        pdf.move_down 6
      end
    end

    def render_certifications(pdf)
      return if @resume.certifications.empty?

      section_title(pdf, 'Certifications')
      @resume.certifications.order(:position).each do |cert|
        line = [cert.name, cert.issuer].compact.join(' — ')
        pdf.text line, size: 10
        dates = [cert.issue_date, cert.expiry_date].compact.map { |d| d.strftime('%b %Y') }.join(' — ')
        pdf.text dates, size: 9, color: '666666' if dates.present?
        pdf.text cert.url, size: 9 if cert.url.present?
        pdf.move_down 4
      end
    end

    def render_skills(pdf)
      return if @resume.skills.empty?

      section_title(pdf, 'Skills')
      Skill::CATEGORIES.each do |category|
        names = @resume.skills.where(category:).order(:position).pluck(:name)
        next if names.empty?

        pdf.text category.titleize, size: 10, style: :bold
        pdf.text names.join(', '), size: 10
        pdf.move_down 4
      end
    end

    def render_projects(pdf)
      return if @resume.projects.empty?

      section_title(pdf, 'Projects & Publications')
      @resume.projects.order(:position).each do |project|
        pdf.text project.title, size: 11, style: :bold
        pdf.text [project.role, project.date].compact.join(' — '), size: 9, color: '666666'
        pdf.text project.description.to_s, size: 10 if project.description.present?
        pdf.text project.url, size: 9 if project.url.present?
        pdf.move_down 6
      end
    end

    def render_additional_sections(pdf)
      render_json_list(pdf, 'Languages', @profile&.languages, keys: %w[name proficiency level])
      render_json_list(pdf, 'Awards', @profile&.awards, keys: %w[title name organization date])
      render_json_list(pdf, 'Volunteer Experience', @profile&.volunteer_experiences, keys: %w[role organization description date])
      render_json_list(pdf, 'References', @profile&.references, keys: %w[name title contact email phone])
      render_interests(pdf)
      render_job_preferences(pdf)
    end

    def render_json_list(pdf, title, items, keys:)
      list = Array(items)
      return if list.empty?

      section_title(pdf, title)
      list.each do |item|
        next unless item.is_a?(Hash)

        values = keys.filter_map { |key| item[key] || item[key.to_sym] }.compact
        pdf.text values.join(' — '), size: 10
      end
      pdf.move_down 8
    end

    def render_interests(pdf)
      interests = Array(@profile&.interests)
      return if interests.empty?

      section_title(pdf, 'Interests')
      pdf.text interests.join(', '), size: 10
      pdf.move_down 8
    end

    def render_job_preferences(pdf)
      prefs = @profile&.job_preferences
      return if prefs.blank?

      section_title(pdf, 'Job Preferences')
      modes = %w[remote hybrid onsite].filter { |mode| prefs[mode] || prefs[mode.to_sym] }
      pdf.text "Preferred work modes: #{modes.join(', ').titleize}", size: 10 if modes.any?
    end

    def section_title(pdf, title)
      pdf.text title.upcase, size: 12, style: :bold
      pdf.move_down 4
    end

    def bullet_list(pdf, items, prefix: '')
      Array(items).each do |item|
        next if item.blank?

        pdf.text "• #{prefix}#{item}", size: 10, leading: 2
      end
    end

    def location_label
      return nil if @profile.blank?

      [@profile.location_city, @profile.location_country].compact.join(', ').presence
    end

    def format_date_range(start_date, end_date, current)
      start_label = start_date&.strftime('%b %Y')
      end_label = current ? 'Present' : end_date&.strftime('%b %Y')
      [start_label, end_label].compact.join(' — ')
    end
  end
end
