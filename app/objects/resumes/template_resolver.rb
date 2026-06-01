# frozen_string_literal: true

module Resumes
  module TemplateResolver
    module_function

    def resolve_slug!(slug)
      Template.find_by!(slug: slug)
    end

    def apply_template_slug!(resume, slug)
      return if slug.blank?

      resume.template = resolve_slug!(slug)
    end
  end
end
