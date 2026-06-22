# frozen_string_literal: true

module Seeds
  # Seeds the resume-editor dropdowns with the lists that used to be hardcoded in
  # the frontend, plus a sensible starter vocabulary for the fields that were
  # previously free-text. Everything seeded here is `approved` (curated). Idempotent.
  module Lookups
    module_function

    COUNTRIES = [
      'Ethiopia', 'Kenya', 'United Arab Emirates', 'United States', 'United Kingdom',
      'Canada', 'Germany', 'Saudi Arabia', 'Qatar', 'South Africa', 'Nigeria', 'Egypt'
    ].freeze

    CITIES = [
      'Addis Ababa', 'Dire Dawa', 'Adama', 'Bahir Dar', 'Hawassa',
      'Mekelle', 'Gondar', 'Jimma', 'Dessie', 'Nairobi', 'Dubai'
    ].freeze

    JOB_TITLES = [
      'Software Engineer', 'Frontend Developer', 'Backend Developer', 'Full Stack Developer',
      'Project Manager', 'Product Manager', 'Accountant', 'Customer Support Specialist',
      'Data Analyst', 'UI/UX Designer', 'Sales Representative', 'Marketing Manager'
    ].freeze

    INDUSTRIES = %w[
      Technology Finance Healthcare Education Nonprofit
      Manufacturing Retail Hospitality Construction Telecommunications Agriculture
    ].freeze

    DEGREES = [
      'High School Diploma', 'Certificate', 'Diploma', 'Associate Degree',
      'Bachelor of Science', 'Bachelor of Arts', 'Master of Science', 'Master of Arts',
      'Master of Business Administration', 'Doctor of Philosophy'
    ].freeze

    FIELDS_OF_STUDY = [
      'Computer Science', 'Software Engineering', 'Information Technology', 'Information Systems',
      'Business Administration', 'Accounting', 'Economics', 'Marketing', 'Finance',
      'Mechanical Engineering', 'Civil Engineering', 'Electrical Engineering',
      'Medicine', 'Nursing', 'Law', 'Architecture'
    ].freeze

    TECHNOLOGIES = [
      'React', 'TypeScript', 'JavaScript', 'Node.js', 'Python', 'Ruby on Rails',
      'PostgreSQL', 'Docker', 'AWS', 'Figma', 'Excel', 'Git'
    ].freeze

    LANGUAGES = [
      'Amharic', 'English', 'Afaan Oromo', 'Tigrinya', 'Somali',
      'Arabic', 'French', 'Spanish', 'German', 'Mandarin', 'Swahili'
    ].freeze

    LANGUAGE_PROFICIENCIES = %w[Native Fluent Professional Intermediate Basic].freeze

    INTERESTS = %w[
      Reading Photography Traveling Volunteering Music
      Football Running Cooking Hiking Chess Blogging
    ].freeze

    SKILLS = {
      'technical' => ['React', 'TypeScript', 'Ruby on Rails', 'SQL', 'Python', 'JavaScript', 'Node.js'],
      'soft' => ['Communication', 'Leadership', 'Teamwork', 'Problem Solving', 'Time Management', 'Adaptability'],
      'tools' => %w[Excel Figma Jira Git Notion Slack Trello]
    }.freeze

    def seed!
      seed_list(Country, COUNTRIES)
      seed_list(City, CITIES)
      seed_list(JobTitle, JOB_TITLES)
      seed_list(Industry, INDUSTRIES)
      seed_list(Degree, DEGREES)
      seed_list(FieldOfStudy, FIELDS_OF_STUDY)
      seed_list(Technology, TECHNOLOGIES)
      seed_list(Language, LANGUAGES)
      seed_list(LanguageProficiency, LANGUAGE_PROFICIENCIES)
      seed_list(Interest, INTERESTS)
      seed_skills!
    end

    def seed_list(model, values)
      values.each_with_index do |value, index|
        record = model.find_or_initialize_by(normalized_value: model.normalize_value(value))
        record.update!(value:, status: 'approved', position: values.length - index)
      end
    end

    def seed_skills!
      SKILLS.each do |category, values|
        values.each_with_index do |value, index|
          record = SkillOption.find_or_initialize_by(
            normalized_value: SkillOption.normalize_value(value), category:
          )
          record.update!(value:, status: 'approved', position: values.length - index)
        end
      end
    end
  end
end
