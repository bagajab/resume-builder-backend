# frozen_string_literal: true

module Resumes
  # Onboarding "upload your resume" pipeline: validate the upload, normalize it
  # to a model-readable document (converting DOC/DOCX to PDF), parse it into the
  # draft-params shape via the configured provider (Resumes::ResumeParser), then
  # canonicalize lookup-backed values and persist a new resume via the existing
  # Resumes::DraftUpdater.
  #
  # Parsing/conversion (slow, network + shell) run OUTSIDE the DB transaction;
  # only the persistence step is transactional.
  class ResumeImporter
    PDF_TYPE = 'application/pdf'
    IMAGE_TYPES = %w[image/jpeg image/png image/webp].freeze
    DOC_TYPES = %w[
      application/msword
      application/vnd.openxmlformats-officedocument.wordprocessingml.document
    ].freeze
    EXTENSION_TYPES = {
      '.pdf' => PDF_TYPE,
      '.png' => 'image/png',
      '.jpg' => 'image/jpeg',
      '.jpeg' => 'image/jpeg',
      '.webp' => 'image/webp'
    }.freeze
    DOC_EXTENSIONS = %w[.doc .docx].freeze
    MAX_SIZE = 10.megabytes

    def initialize(user:, file:)
      @user = user
      @file = file
    end

    # @return [Resume] the persisted, pre-filled resume
    def call
      validate!
      data, media_type = prepare_document
      parsed = ResumeParser.build(data: data, media_type: media_type).call
      persist(parsed)
    end

    private

    def validate!
      raise ImportError, 'Please choose a file to upload.' if @file.blank?
      raise ImportError, 'That file is too large — the maximum is 10 MB.' if @file.size > MAX_SIZE
      return if word_document? || EXTENSION_TYPES.key?(extension) || supported_native_type?

      raise ImportError, 'Unsupported file type. Upload a PDF, Word document, or image.'
    end

    # @return [Array(String, String)] (document bytes, IANA media_type)
    def prepare_document
      bytes = @file.read
      if word_document?
        [DocumentConverter.new(data: bytes, extension: word_extension).call, PDF_TYPE]
      else
        [bytes, native_media_type]
      end
    end

    def persist(parsed)
      ActiveRecord::Base.transaction do
        LookupMapper.new(user: @user).map!(parsed)
        resume = @user.resumes.create!(title: resume_title(parsed), status: 'draft')
        Resumes::DraftUpdater.new(resume, parsed).call
      end
    end

    def word_document?
      DOC_TYPES.include?(content_type) || DOC_EXTENSIONS.include?(extension)
    end

    def supported_native_type?
      content_type == PDF_TYPE || IMAGE_TYPES.include?(content_type)
    end

    # Prefer the upload's content_type; fall back to the file extension when the
    # browser sends a generic type (e.g. application/octet-stream).
    def native_media_type
      return content_type if supported_native_type?

      EXTENSION_TYPES.fetch(extension)
    end

    def word_extension
      DOC_EXTENSIONS.include?(extension) ? extension : '.docx'
    end

    def resume_title(parsed)
      parsed[:title].presence ||
        parsed.dig(:profile, :full_name).presence&.then { |name| "#{name} — Resume" } ||
        'Imported Resume'
    end

    def content_type
      @file.content_type.to_s
    end

    def extension
      File.extname(@file.original_filename.to_s).downcase
    end
  end
end
