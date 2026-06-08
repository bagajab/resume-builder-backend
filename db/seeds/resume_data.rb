# frozen_string_literal: true

module Seeds
  module ResumeData
    SAMPLE_USERS = [
      { first_name: 'Alice', last_name: 'Johnson', email: 'alice@example.com', job_title: 'Senior Software Engineer', industry: 'Technology' },
      { first_name: 'Bob', last_name: 'Smith', email: 'bob@example.com', job_title: 'Product Manager', industry: 'SaaS' },
      { first_name: 'Carol', last_name: 'Williams', email: 'carol@example.com', job_title: 'UX Designer', industry: 'Design' },
      { first_name: 'David', last_name: 'Brown', email: 'david@example.com', job_title: 'Data Scientist', industry: 'Analytics' },
      { first_name: 'Emma', last_name: 'Davis', email: 'emma@example.com', job_title: 'DevOps Engineer', industry: 'Cloud Infrastructure' },
      { first_name: 'Frank', last_name: 'Miller', email: 'frank@example.com', job_title: 'Full Stack Developer', industry: 'E-commerce' },
      { first_name: 'Grace', last_name: 'Wilson', email: 'grace@example.com', job_title: 'Marketing Director', industry: 'Digital Marketing' },
      { first_name: 'Henry', last_name: 'Taylor', email: 'henry@example.com', job_title: 'Security Engineer', industry: 'Cybersecurity' },
      { first_name: 'Ivy', last_name: 'Anderson', email: 'ivy@example.com', job_title: 'Machine Learning Engineer', industry: 'AI/ML' },
      { first_name: 'Jack', last_name: 'Thomas', email: 'jack@example.com', job_title: 'Technical Writer', industry: 'Documentation' }
    ].freeze

    module_function

    def ensure_templates!
      Template.find_or_create_by!(slug: 'professional') do |template|
        template.name = 'Professional'
        template.description = 'Two-column executive layout with accent headings and structured entries'
      end

      Template.find_or_create_by!(slug: 'spotlight') do |template|
        template.name = 'Spotlight'
        template.description = 'Two-column layout with a bold indigo sidebar, skill meters, language rings and section badges'
      end
    end

    def seed!
      return unless Rails.env.development?

      ensure_templates!

      puts 'Seeding sample users and resumes...'

      SAMPLE_USERS.each_with_index do |user_data, index|
        user = User.find_or_initialize_by(email: user_data[:email])
        user.assign_attributes(
          first_name: user_data[:first_name],
          last_name: user_data[:last_name],
          password: 'password',
          password_confirmation: 'password'
        )
        user.save!

        create_base_resume(user, user_data, index)
      end

      puts "Seeded #{SAMPLE_USERS.size} users with resumes."
    end

    def create_base_resume(user, user_data, index)
      return if user.resumes.originals.exists?

      template = Template.find_by!(slug: %w[classic modern minimal professional][index % 4])
      full_name = "#{user_data[:first_name]} #{user_data[:last_name]}"

      resume = user.resumes.create!(
        title: "#{full_name} — #{user_data[:job_title]}",
        status: 'completed',
        current_step: 6,
        template: template,
        version: 1
      )

      resume.create_profile!(profile_attrs(user_data, full_name))
      create_experiences(resume, user_data)
      create_educations(resume, index)
      create_skills(resume, user_data)
      create_projects(resume, user_data)
      create_certifications(resume, user_data)

      create_derived_versions(user, resume, index)
    end

    def profile_attrs(user_data, full_name)
      {
        full_name: full_name,
        phone: "+1 (555) #{100 + rand(900)}-#{1000 + rand(9000)}",
        location_city: %w[San Francisco New York Austin Seattle Boston][rand(5)],
        location_country: 'USA',
        linkedin_url: "https://linkedin.com/in/#{full_name.parameterize}",
        github_url: "https://github.com/#{user_data[:first_name].downcase}dev",
        portfolio_url: "https://#{user_data[:first_name].downcase}.dev",
        job_title: user_data[:job_title],
        years_of_experience: 3 + rand(12),
        industry: user_data[:industry],
        career_summary: "Experienced #{user_data[:job_title].downcase} with a passion for building " \
                        "innovative solutions in #{user_data[:industry]}. Proven track record of delivering " \
                        'high-quality results in fast-paced environments.',
        languages: [
          { name: 'English', proficiency: 'Native' },
          { name: 'Spanish', proficiency: 'Professional' }
        ],
        awards: [
          { title: 'Employee of the Year', organization: 'Tech Corp', date: '2023' }
        ],
        volunteer_experiences: [
          { role: 'Mentor', organization: 'Code for Good', description: 'Mentored junior developers', date: '2022–Present' }
        ],
        references: [
          { name: 'Jane Manager', title: 'Engineering Director', contact: 'jane@techcorp.com' }
        ],
        interests: %w[Open Source Hiking Photography],
        job_preferences: { remote: true, hybrid: true, onsite: false }
      }
    end

    def create_experiences(resume, user_data)
      companies = [
        { company: 'Tech Corp', title: user_data[:job_title], current: true },
        { company: 'StartupXYZ', title: "Junior #{user_data[:job_title]}", current: false }
      ]

      companies.each_with_index do |exp, i|
        resume.experiences.create!(
          job_title: exp[:title],
          company: exp[:company],
          location: 'Remote',
          start_date: Date.new(2020 + i, 1, 1),
          end_date: exp[:current] ? nil : Date.new(2022, 12, 31),
          current: exp[:current],
          responsibilities: [
            "Led development of key #{user_data[:industry].downcase} initiatives",
            'Collaborated with cross-functional teams to deliver projects on time',
            'Mentored junior team members and conducted code reviews'
          ],
          achievements: [
            'Increased team productivity by 30%',
            'Reduced deployment time by 50%'
          ],
          technologies: %w[Ruby Rails React PostgreSQL Docker],
          position: i
        )
      end
    end

    def create_educations(resume, index)
      institutions = [
        { institution: 'Stanford University', degree: 'B.S.', field: 'Computer Science' },
        { institution: 'MIT', degree: 'M.S.', field: 'Software Engineering' }
      ]

      institutions.each_with_index do |edu, i|
        resume.educations.create!(
          institution: edu[:institution],
          degree: edu[:degree],
          field_of_study: edu[:field],
          start_year: 2010 + index + i,
          end_year: 2014 + index + i,
          gpa: '3.8',
          honors: i.zero? ? 'Summa Cum Laude' : nil,
          position: i
        )
      end
    end

    def create_skills(resume, user_data)
      technical = case user_data[:industry]
                  when 'Design' then %w[Figma Sketch Adobe XD Prototyping]
                  when 'Analytics' then %w[Python R SQL TensorFlow Pandas]
                  when 'Cybersecurity' then %w[Penetration Testing SIEM OWASP Burp Suite]
                  else %w[JavaScript TypeScript Ruby Python React Node.js]
                  end

      technical.each_with_index { |name, i| resume.skills.create!(name:, category: 'technical', position: i) }
      %w[Leadership Communication Problem Solving].each_with_index do |name, i|
        resume.skills.create!(name:, category: 'soft', position: i + technical.size)
      end
      %w[Git Docker AWS Jira].each_with_index do |name, i|
        resume.skills.create!(name:, category: 'tools', position: i + technical.size + 3)
      end
    end

    def create_projects(resume, user_data)
      resume.projects.create!(
        title: "#{user_data[:industry]} Platform",
        description: "Built a scalable platform serving 10K+ users in the #{user_data[:industry].downcase} space.",
        url: 'https://github.com/example/project',
        date: '2023',
        role: 'Lead Developer',
        position: 0
      )
      resume.projects.create!(
        title: 'Open Source Contribution',
        description: 'Contributed core features to a popular open-source library with 5K+ GitHub stars.',
        url: 'https://github.com/example/oss',
        date: '2022',
        role: 'Contributor',
        position: 1
      )
    end

    def create_certifications(resume, user_data)
      certs = [
        { name: 'AWS Solutions Architect', issuer: 'Amazon Web Services' },
        { name: 'Professional Scrum Master', issuer: 'Scrum.org' }
      ]

      certs.each_with_index do |cert, i|
        resume.certifications.create!(
          name: cert[:name],
          issuer: cert[:issuer],
          issue_date: Date.new(2022 + i, 6, 1),
          expiry_date: Date.new(2025 + i, 6, 1),
          url: "https://cert.example.com/#{cert[:name].parameterize}",
          position: i
        )
      end
    end

    def create_derived_versions(user, base_resume, index)
      derived_templates = Template.where.not(id: base_resume.template_id).ordered.limit(2)

      derived_templates.each_with_index do |template, i|
        derived = base_resume.duplicate_for(user)
        derived.update!(
          title: "#{base_resume.title} — #{template.name} Version",
          template: template,
          status: 'draft'
        )

        # Simulate edits on derived resume without touching the original
        derived.profile.update!(career_summary: "#{derived.profile.career_summary} Tailored for #{template.name} presentation.")
        derived.experiences.first&.update!(
          job_title: "#{derived.experiences.first.job_title} (#{template.slug.capitalize} focus)"
        )
      end
    end
  end
end
