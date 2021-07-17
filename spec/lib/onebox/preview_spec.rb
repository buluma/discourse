# frozen_string_literal: true

require "rails_helper"

describe Onebox::Preview do
  before do
    stub_request(:get, "https://www.amazon.com/product")
      .to_return(status: 200, body: onebox_response("amazon"))
  end

  let(:preview_url) { "http://www.amazon.com/product" }
  let(:preview) { described_class.new(preview_url) }

  describe "#to_s" do
    before do
      stub_request(:get, "https://www.amazon.com/Seven-Languages-Weeks-Programming-Programmers/dp/193435659X")
        .to_return(status: 200, body: onebox_response("amazon"))
    end

    it "returns some html if given a valid url" do
      title = "Seven Languages in Seven Weeks: A Pragmatic Guide to Learning Programming Languages (Pragmatic Programmers)"
      expect(preview.to_s).to include(title)
    end

    it "returns an empty string if the url is not valid" do
      expect(described_class.new('not a url').to_s).to eq("")
    end
  end

  describe "max_width" do
    let(:iframe_html) { '<iframe src="//player.vimeo.com/video/96017582" width="1280" height="720" frameborder="0" title="GO BIG OR GO HOME" webkitallowfullscreen mozallowfullscreen allowfullscreen></iframe>' }

    it "doesn't change dimensions without an option" do
      iframe = described_class.new(preview_url)
      iframe.stubs(:engine_html).returns(iframe_html)

      result = iframe.to_s
      expect(result).to include("width=\"1280\"")
      expect(result).to include("height=\"720\"")
    end

    it "doesn't change dimensions if it is smaller than `max_width`" do
      iframe = described_class.new(preview_url, max_width: 2000)
      iframe.stubs(:engine_html).returns(iframe_html)

      result = iframe.to_s
      expect(result).to include("width=\"1280\"")
      expect(result).to include("height=\"720\"")
    end

    it "changes dimensions if larger than `max_width`" do
      iframe = described_class.new(preview_url, max_width: 900)
      iframe.stubs(:engine_html).returns(iframe_html)

      result = iframe.to_s
      expect(result).to include("width=\"900\"")
      expect(result).to include("height=\"506\"")
    end
  end

  describe "#engine" do
    it "returns an engine" do
      expect(preview.send(:engine)).to be_an(Onebox::Engine)
    end
  end

  describe "xss" do
    let(:xss) { "wat' onerror='alert(/XSS/)" }
    let(:img_html) { "<img src='#{xss}'>" }

    it "prevents XSS" do
      preview = described_class.new(preview_url)
      preview.stubs(:engine_html).returns(img_html)

      result = preview.to_s
      expect(result).not_to match(/onerror/)
    end
  end

  describe "iframe sanitizer" do
    let(:iframe_html) { "<iframe src='https://thirdparty.example.com'>" }

    it "sanitizes iframes from unknown origins" do
      preview = described_class.new(preview_url)
      preview.stubs(:engine_html).returns(iframe_html)

      result = preview.to_s
      expect(result).not_to include(' src="https://thirdparty.example.com"')
      expect(result).to include(' data-unsanitized-src="https://thirdparty.example.com"')
    end

    it "allows allowed origins" do
      preview = described_class.new(preview_url, allowed_iframe_origins: ["https://thirdparty.example.com"])
      preview.stubs(:engine_html).returns(iframe_html)

      result = preview.to_s
      expect(result).to include ' src="https://thirdparty.example.com"'
    end

    it "allows wildcard allowed origins" do
      preview = described_class.new(preview_url, allowed_iframe_origins: ["https://*.example.com"])
      preview.stubs(:engine_html).returns(iframe_html)

      result = preview.to_s
      expect(result).to include ' src="https://thirdparty.example.com"'
    end
  end
end
