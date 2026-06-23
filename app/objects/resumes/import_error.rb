# frozen_string_literal: true

module Resumes
  # Raised by the resume-import pipeline (ResumeImporter, DocumentConverter,
  # ResumeParser) when an uploaded file can't be turned into a resume — an
  # unsupported file, a failed DOC/DOCX conversion, or an Anthropic call that
  # failed or returned unreadable content. The message is user-facing; rendered
  # as a friendly 422 by API::V1::APIController.
  class ImportError < StandardError; end
end
