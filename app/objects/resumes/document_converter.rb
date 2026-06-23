# frozen_string_literal: true

require 'open3'
require 'tmpdir'

module Resumes
  # Converts an uploaded DOC/DOCX (binary string) to PDF bytes using headless
  # LibreOffice (`soffice`). The Anthropic API only accepts PDF and image
  # documents, so Word uploads are normalized to PDF before parsing.
  #
  # Each invocation runs in an isolated temp dir with a private LibreOffice
  # user-profile (`-env:UserInstallation=…`) so concurrent conversions don't
  # contend on the default profile lock.
  class DocumentConverter
    SOFFICE_BIN = ENV.fetch('SOFFICE_BIN', 'soffice')
    ALLOWED_EXTENSIONS = %w[.doc .docx].freeze
    DEFAULT_EXTENSION = '.docx'

    def initialize(data:, extension: DEFAULT_EXTENSION)
      @data = data
      # Pin to a frozen allowlist so the temp filename passed to soffice can
      # never carry caller-supplied data into the command invocation.
      normalized = extension.to_s.downcase
      normalized = ".#{normalized}" unless normalized.start_with?('.')
      @extension = ALLOWED_EXTENSIONS.include?(normalized) ? normalized : DEFAULT_EXTENSION
    end

    # @return [String] the converted PDF as a binary string
    def call
      Dir.mktmpdir('resume-import') do |dir|
        input = File.join(dir, "source#{@extension}")
        File.binwrite(input, @data)

        run_soffice(dir, input)

        output = Dir.glob(File.join(dir, '*.pdf')).first
        raise ImportError, 'Could not convert the document to PDF.' if output.nil?

        File.binread(output)
      end
    end

    private

    def run_soffice(dir, input)
      profile = "file://#{File.join(dir, '.libreoffice')}"
      cmd = [
        SOFFICE_BIN, '--headless', '--norestore',
        "-env:UserInstallation=#{profile}",
        '--convert-to', 'pdf', '--outdir', dir, input
      ]
      output, status = Open3.capture2e({ 'HOME' => dir }, *cmd)
      return if status.success?

      raise ImportError, "LibreOffice conversion failed: #{output.strip}"
    rescue Errno::ENOENT
      raise ImportError, 'LibreOffice (soffice) is not installed on the server.'
    end
  end
end
