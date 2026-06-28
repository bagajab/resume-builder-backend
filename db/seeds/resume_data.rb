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

    BILILIGN_USER = {
      first_name: 'Bililign',
      last_name: 'Niguse Feredegn',
      email: 'bililignniguse1@gmail.com',
      job_title: 'Public Health Professional',
      industry: 'Public Health'
    }.freeze

    BAGAJA_USER = {
      first_name: 'Bagaja',
      last_name: 'Birhanu Nura',
      email: 'bagajab@gmail.com',
      job_title: 'Senior Digital Solutions Engineer',
      industry: 'Digital Health & Technology'
    }.freeze

    module_function

    TEMPLATES = [
      { slug: 'spotlight', name: 'Spotlight', description: 'Two-column layout with a bold indigo sidebar, skill meters, language rings and section badges' },
      { slug: 'double', name: 'Double Column', description: 'Clean two-column layout with a contact header, photo, icon-badged achievements and interests, courses, skills and dotted language meters' },
      { slug: 'crisp', name: 'Crisp', description: 'Bold full-width accent banner header with a two-column body — summary, experience, education and dotted languages alongside icon-led achievements, underlined skills, courses and interests' },
      { slug: 'clarity', name: 'Clarity', description: 'Airy two-column layout with an accent name header and dotted corner motif — summary, accent skill pills, experience and dotted languages alongside icon-led achievements, courses, education and interests' },
      { slug: 'polished', name: 'Polished', description: 'Executive two-column layout with a plain header, bold black section rules, comma-separated skills and bar-meter languages alongside achievements, education, courses and interests' },
      { slug: 'elegant', name: 'Elegant', description: 'Refined single-column layout with centered serif headings, a monochrome palette and a three-column key achievements grid' },
      { slug: 'meridian', name: 'Meridian', description: 'Two-column layout with a bold dark sidebar carrying the photo, achievements, education, skills and courses beside a light main column' },
      { slug: 'vertex', name: 'Vertex', description: 'Single-column layout with heavy section rules, a blue accent, a two-column achievements grid, bar-meter languages and comma-separated core competencies' },
      { slug: 'aspect', name: 'Aspect', description: 'Two-column layout with a light sidebar carrying the photo, achievements, education, skills, courses and interests beside the main experience column' },
      { slug: 'timeline', name: 'Timeline', description: 'Single-column layout with a vertical timeline rail for experience and education, underlined skill chips and progress-bar languages' },
      { slug: 'adwa', name: 'Adwa Sentinel', description: 'Two-column layout with a refined ink-navy sidebar carrying the photo, summary, gradient skill rows, dot-meter languages and awards beside a warm-ivory main column with Fraunces editorial rule headings, gold diamond bullets and a vertical timeline rail' },
      { slug: 'yegna', name: 'Yegna Editorial', description: 'Magazine-styled two-column layout with a deep-maroon serif sidebar carrying the photo, summary, comma-separated skills, languages and certifications beside a cream main column with ruled headings and dash bullets' },
      { slug: 'gondar', name: 'Slate Modern', description: 'Two-column layout with a charcoal-slate sidebar carrying the photo, summary, two-column skill grid, dot-meter languages and awards beside a cool-white main column with warm-copper Space Grotesk rule headings, dash bullets and a vertical timeline rail' }
    ].freeze

    def ensure_templates!
      TEMPLATES.each do |attrs|
        Template.find_or_create_by!(slug: attrs[:slug]) do |template|
          template.name = attrs[:name]
          template.description = attrs[:description]
        end
      end
    end

    def seed!
      # return unless Rails.env.development?

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

      puts "Seeded #{SAMPLE_USERS.size} sample users with resumes."

      user = User.find_or_initialize_by(email: BILILIGN_USER[:email])
      user.assign_attributes(
        first_name: BILILIGN_USER[:first_name],
        last_name: BILILIGN_USER[:last_name],
        password: 'password',
        password_confirmation: 'password'
      )
      user.save!

      create_bililign_resume(user)

      puts 'Seeded Bililign Niguse Feredegn with resume.'

      user = User.find_or_initialize_by(email: BAGAJA_USER[:email])
      user.assign_attributes(
        first_name: BAGAJA_USER[:first_name],
        last_name: BAGAJA_USER[:last_name],
        password: 'password',
        password_confirmation: 'password'
      )
      user.save!

      create_bagaja_resume(user)

      puts 'Seeded Bagaja Birhanu Nura with resume.'
    end

    def create_bililign_resume(user)
      return if user.resumes.originals.exists?

      template = Template.find_by!(slug: 'spotlight')
      full_name = 'Bililign Niguse Feredegn'

      resume = user.resumes.create!(
        title: "#{full_name} — #{BILILIGN_USER[:job_title]}",
        status: 'completed',
        current_step: 6,
        template: template,
        version: 1
      )

      resume.create_profile!(
        full_name: full_name,
        phone: nil,
        location_city: nil,
        location_country: 'Ethiopia',
        job_title: BILILIGN_USER[:job_title],
        years_of_experience: 1,
        industry: BILILIGN_USER[:industry],
        career_summary: 'Recent Bachelor of Science graduate in Public Health with hands-on community health ' \
                        'experience, strong academic performance, and demonstrated leadership as a class representative. ' \
                        'Passionate about health education, environmental sanitation, and collaborative service delivery.',
        languages: [
          { name: 'English', proficiency: 'Fluent' },
          { name: 'Amharic', proficiency: 'Fluent' },
          { name: 'Afaan Oromo', proficiency: 'Fluent' }
        ],
        awards: [
          {
            title: 'Certificate of Appreciation',
            organization: 'Geneme Health Center',
            date: 'Jan 2026'
          }
        ],
        volunteer_experiences: [
          {
            role: 'Member',
            organization: 'Ethiopian Health Profession Students Association (EHPSA), Wolaita Sodo Branch',
            description: 'Participated in student-led professional development and public health activities. ' \
                         'Engaged in initiatives promoting health awareness and community service.',
            date: '2025–2026'
          }
        ],
        references: [],
        interests: %w[Community Health Public Health Advocacy Professional Development],
        job_preferences: { remote: false, hybrid: true, onsite: true }
      )

      resume.experiences.create!(
        job_title: 'Class Representative',
        company: 'Wolaita Sodo University',
        location: 'Ethiopia',
        start_date: nil,
        end_date: nil,
        current: true,
        responsibilities: [
          'Represented students and communicated academic concerns between students and faculty.',
          'Coordinated class activities and promoted collaboration among students.',
          'Demonstrated leadership, responsibility, and problem-solving skills.'
        ],
        achievements: [],
        technologies: [],
        position: 0
      )

      resume.experiences.create!(
        job_title: 'Public Health Trainee',
        company: 'Geneme Health Center',
        location: 'Ethiopia',
        start_date: Date.new(2025, 12, 1),
        end_date: Date.new(2026, 1, 31),
        current: false,
        responsibilities: [
          'Conducted health education and community awareness activities.',
          'Participated in environmental sanitation initiatives and routine health data collection.',
          'Collaborated with healthcare professionals to support service delivery and community health programs.'
        ],
        achievements: [
          'Received a Certificate of Appreciation for dedication and performance.'
        ],
        technologies: [],
        position: 1
      )

      resume.educations.create!(
        institution: 'Wolaita Sodo University',
        degree: 'Bachelor of Science (BSc)',
        field_of_study: 'Public Health',
        start_year: nil,
        end_year: 2026,
        gpa: '3.54/4.00',
        honors: 'Passed the Ethiopian National University Exit Examination. ' \
                'Grade 8 Regional Examination Score: 91.88%. ' \
                'Maintained strong academic performance throughout secondary school and university.',
        position: 0
      )

      [
        { name: 'Leadership and Team Coordination', category: 'soft' },
        { name: 'Public Health Research and Data Collection', category: 'technical' },
        { name: 'Community Health Promotion', category: 'technical' },
        { name: 'Problem Solving and Analytical Thinking', category: 'soft' },
        { name: 'Microsoft Word', category: 'tools' },
        { name: 'Microsoft Excel', category: 'tools' },
        { name: 'Microsoft PowerPoint', category: 'tools' }
      ].each_with_index do |skill, i|
        resume.skills.create!(name: skill[:name], category: skill[:category], position: i)
      end

      resume.certifications.create!(
        name: 'Certificate of Appreciation',
        issuer: 'Geneme Health Center',
        issue_date: Date.new(2026, 1, 31),
        expiry_date: nil,
        url: nil,
        position: 0
      )

      create_derived_versions(user, resume)
    end

    def create_bagaja_resume(user)
      return if user.resumes.originals.exists?

      template = Template.find_by!(slug: 'spotlight')
      full_name = 'Bagaja Birhanu Nura'

      resume = user.resumes.create!(
        title: "#{full_name} — #{BAGAJA_USER[:job_title]}",
        status: 'completed',
        current_step: 6,
        template: template,
        version: 1
      )

      resume.create_profile!(
        full_name: full_name,
        phone: '+251-916-382434',
        location_city: 'Addis Ababa',
        location_country: 'Ethiopia',
        github_url: 'https://github.com/bagajab',
        portfolio_url: 'https://www.bagaja.dev',
        job_title: BAGAJA_USER[:job_title],
        years_of_experience: 9,
        industry: BAGAJA_USER[:industry],
        career_summary: 'Digital Development and Technology Specialist with 9+ years of experience designing ' \
                        'and scaling digital services for millions of users across Ethiopia. Experienced in ' \
                        'SMS-based communication systems, user-centered product design, interoperability, ' \
                        'stakeholder engagement, and nationwide digital transformation initiatives. Skilled at ' \
                        'translating complex technical and program requirements into practical digital solutions ' \
                        'for underserved populations. Passionate about applying technology, data, and behavioral ' \
                        'insights to improve outcomes for smallholder farmers and rural communities.',
        languages: [
          { name: 'English', proficiency: 'Fluent' },
          { name: 'Amharic', proficiency: 'Native' }
        ],
        awards: [],
        volunteer_experiences: [],
        references: [],
        interests: %w[
          Digital Health
          Interoperability
          Open Source
          Rural Development
          User-Centered Design
        ],
        job_preferences: { remote: true, hybrid: true, onsite: true }
      )

      resume.experiences.create!(
        job_title: 'Digital Advisor | Software Engineer',
        company: 'UNICEF EHIS',
        location: 'Addis Ababa, Ethiopia',
        start_date: Date.new(2025, 9, 1),
        end_date: nil,
        current: true,
        responsibilities: [
          'Designed and maintained SMS-based communication workflows and automated alerts reaching beneficiaries through basic mobile phones and low-bandwidth networks.',
          'Conducted user needs assessments and stakeholder consultations to identify service gaps and improve digital product adoption.',
          'Worked directly with field teams and operational staff to gather feedback, validate requirements, and refine workflows.',
          'Developed user-centered digital services tailored for resource-constrained environments.',
          'Evaluated platform interoperability, API maturity, and integration readiness to support scalable digital ecosystems.',
          'Supported training and capacity building for end users and operational teams.',
          'Collaborated with regional implementation teams and operational users to gather field feedback and improve service delivery workflows.',
          'Participated in requirements validation sessions with local stakeholders to ensure solutions aligned with user needs and operational realities.'
        ],
        achievements: [],
        technologies: %w[SMS APIs User-Centered Design],
        position: 0
      )

      resume.experiences.create!(
        job_title: 'Consultant — openIMIS Sandbox Setup',
        company: 'management4health (m4Health)',
        location: 'Addis Ababa, Ethiopia',
        start_date: Date.new(2025, 3, 1),
        end_date: nil,
        current: true,
        responsibilities: [
          'Evaluated platform architecture and API maturity to build scalable interoperability sandboxes, ensuring secure, standardized data exchange across complex institutional ecosystems.',
          'Led the end-to-end setup of an openIMIS interoperability sandbox for GIZ, architecting a deployment strategy rooted in OpenHIE and DCI frameworks.',
          'Engineered the seamless integration of openHIM with openIMIS, utilizing mediator patterns to facilitate secure, standardized data exchange across the national health ecosystem.',
          'Pioneered the integration of MOSIP with openIMIS to enable robust, biometrically-backed insuree verification, enhancing the security of enrollment and claims workflows.'
        ],
        achievements: [],
        technologies: %w[openIMIS openHIM OpenHIE MOSIP DCI],
        position: 1
      )

      resume.experiences.create!(
        job_title: 'Senior Full Stack Engineer',
        company: 'management4health (m4Health)',
        location: 'Addis Ababa, Ethiopia',
        start_date: Date.new(2024, 1, 1),
        end_date: Date.new(2024, 11, 30),
        current: false,
        responsibilities: [
          'Successfully transitioned the National Health Insurance System from pilot to full-scale implementation, benefiting millions of Ethiopians.',
          'Led the development and enhancement of the National Health Insurance System, initially piloted by CHAI, ensuring scalability and reliability for nationwide use.',
          'Enhanced system security and performance, ensuring high availability and reliability of health services.',
          'Improved application performance and scalability by containerizing the entire system and using horizontal deployment methods.',
          'Implemented advanced security measures and conducted regular updates and patches to maintain system integrity.',
          'Provided training and support to healthcare workers and system users.'
        ],
        achievements: [
          'Scaled the National Health Insurance System from pilot to nationwide deployment serving millions of beneficiaries.'
        ],
        technologies: %w[Docker Kubernetes Ruby on Rails PostgreSQL],
        position: 2
      )

      resume.experiences.create!(
        job_title: 'Senior Software Engineer',
        company: 'TruLiv',
        location: 'Los Angeles, California, USA (Remote)',
        start_date: Date.new(2022, 2, 1),
        end_date: Date.new(2023, 12, 31),
        current: false,
        responsibilities: [
          'Contributed to the design and development of a cloud-based real estate SaaS platform deployed on AWS, supporting end-to-end investment workflows.',
          'Built and maintained backend services and APIs powering deal sourcing, pipeline management, notifications, and reporting systems.',
          'Worked with data pipeline services to process, aggregate, and analyze real estate data used for pricing, rent comps, and investment insights.',
          'Implemented automated email and in-app notification systems triggered by data and workflow changes across the platform.',
          'Collaborated on cloud deployment, configuration, and operational support to ensure reliability, scalability, and secure production releases.'
        ],
        achievements: [],
        technologies: %w[AWS SaaS APIs Data Pipelines],
        position: 3
      )

      resume.experiences.create!(
        job_title: 'Software Engineer',
        company: 'ICAP',
        location: 'Addis Ababa, Ethiopia',
        start_date: Date.new(2022, 1, 1),
        end_date: Date.new(2022, 2, 28),
        current: false,
        responsibilities: [
          'Developed and refined integration between applications.',
          'Researched and evaluated a variety of eHealth application software products.',
          'Customized Bahmni open source EMR in the Ethiopian context.',
          'Customized and integrated the Ethiopian calendar into the existing application.',
          'Developed a system for data migration from the legacy system and supported the migration process.'
        ],
        achievements: [],
        technologies: %w[Bahmni EMR Open Source],
        position: 4
      )

      resume.experiences.create!(
        job_title: 'Full Stack Engineer',
        company: 'Clinton Health Access Initiative (CHAI)',
        location: 'Addis Ababa, Ethiopia',
        start_date: Date.new(2020, 3, 1),
        end_date: Date.new(2021, 12, 31),
        current: false,
        responsibilities: [
          'Served as technical lead of the insurance management platform developed for EHIA in partnership with the Ethiopian Ministry of Health.',
          'Designed, developed, and implemented new features in the National Health Insurance System platform.',
          'Managed updates, bug fixes, and security patches on the platform.',
          'Managed DevOps activities to ensure uptime and availability of the application.',
          'Designed and implemented an automated rule engine to systematically flag anomalous insurance claims based on predefined medical and business rules, optimizing verification workflows and reducing manual review time.'
        ],
        achievements: [
          'Led technical delivery of the National Health Insurance System pilot used by the entire population of Ethiopia.'
        ],
        technologies: %w[Ruby on Rails DevOps PostgreSQL],
        position: 5
      )

      resume.experiences.create!(
        job_title: 'Programmer',
        company: 'Winner Systems',
        location: 'Addis Ababa, Ethiopia',
        start_date: Date.new(2017, 7, 1),
        end_date: Date.new(2020, 2, 28),
        current: false,
        responsibilities: [
          'Developed backend APIs and enterprise modules for large-scale ERP systems used by multiple public universities.',
          'Built and maintained single-page applications using React and GraphQL backed by Ruby on Rails APIs.',
          'Implemented identity and access workflows, including QR-code-based student identification systems.',
          'Designed and delivered scheduling (class/exam) and reporting modules supporting thousands of concurrent users.',
          'Worked closely with deployment and support teams to deliver reliable production releases across institutions.'
        ],
        achievements: [],
        technologies: %w[Ruby on Rails React GraphQL ERP],
        position: 6
      )

      resume.educations.create!(
        institution: 'Woldia University',
        degree: 'Bachelor of Science (BSc)',
        field_of_study: 'Computer Science',
        start_year: 2013,
        end_year: 2017,
        gpa: nil,
        honors: 'Graduated with High Distinction from the department.',
        position: 0
      )

      [
        { name: 'Digital Platforms & Advisory Systems', category: 'technical' },
        { name: 'SMS & Mobile Communication Systems', category: 'technical' },
        { name: 'API Integration & Interoperability', category: 'technical' },
        { name: 'Data Analysis & Reporting', category: 'technical' },
        { name: 'User-Centered Design', category: 'soft' },
        { name: 'Cloud & Web Technologies', category: 'technical' },
        { name: 'Ruby on Rails', category: 'tools' },
        { name: 'React', category: 'tools' },
        { name: 'GraphQL', category: 'tools' },
        { name: 'AWS', category: 'tools' },
        { name: 'Docker', category: 'tools' },
        { name: 'openIMIS', category: 'tools' },
        { name: 'Stakeholder Engagement', category: 'soft' },
        { name: 'Problem Solving', category: 'soft' }
      ].each_with_index do |skill, i|
        resume.skills.create!(name: skill[:name], category: skill[:category], position: i)
      end

      [
        { name: 'LinkedIn Certified Data Analyst', issuer: 'LinkedIn', year: 2023 },
        { name: 'LinkedIn Certified Project Manager', issuer: 'LinkedIn', year: 2023 },
        { name: 'COVID-19 Contact Tracing', issuer: 'Johns Hopkins University', year: 2020 },
        { name: 'NDG Linux Unhatched', issuer: 'Cisco Networking Academy', year: 2020 }
      ].each_with_index do |cert, i|
        resume.certifications.create!(
          name: cert[:name],
          issuer: cert[:issuer],
          issue_date: Date.new(cert[:year], 6, 1),
          expiry_date: nil,
          url: nil,
          position: i
        )
      end

      create_derived_versions(user, resume)
    end

    def create_base_resume(user, user_data, index)
      return if user.resumes.originals.exists?

      template = Template.find_by!(slug: %w[spotlight double crisp elegant][index % 4])
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

    def create_derived_versions(user, base_resume, index = nil)
      derived_templates = Template.where.not(id: base_resume.template_id).ordered.limit(2)

      derived_templates.each_with_index do |template, i|
        derived = base_resume.duplicate_for(user)
        derived.update!(
          title: "#{base_resume.title} — #{template.name} Version",
          template: template,
          status: 'draft'
        )

        next if index.nil?

        # Simulate edits on derived resume without touching the original
        derived.profile.update!(career_summary: "#{derived.profile.career_summary} Tailored for #{template.name} presentation.")
        derived.experiences.first&.update!(
          job_title: "#{derived.experiences.first.job_title} (#{template.slug.capitalize} focus)"
        )
      end
    end
  end
end
