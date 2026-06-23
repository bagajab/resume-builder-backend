# frozen_string_literal: true

require 'open3'

describe Resumes::DocumentConverter do
  it 'raises a ConversionError when LibreOffice is not installed' do
    stub_const('Resumes::DocumentConverter::SOFFICE_BIN', '/nonexistent/soffice')

    expect { described_class.new(data: 'x', extension: '.docx').call }
      .to raise_error(Resumes::ImportError, /not installed/i)
  end

  it 'raises a ConversionError when the conversion exits non-zero' do
    allow(Open3).to receive(:capture2e)
      .and_return(['could not load filter', instance_double(Process::Status, success?: false)])

    expect { described_class.new(data: 'x', extension: '.docx').call }
      .to raise_error(Resumes::ImportError, /conversion failed/i)
  end

  it 'raises a ConversionError when soffice produces no PDF' do
    allow(Open3).to receive(:capture2e)
      .and_return(['', instance_double(Process::Status, success?: true)])

    expect { described_class.new(data: 'x', extension: '.docx').call }
      .to raise_error(Resumes::ImportError, /convert the document/i)
  end
end
