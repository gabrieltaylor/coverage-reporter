#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

class ReportUrlBuilder
  def initialize(organization_slug, pipeline_slug, build_number, api_token)
    @organization_slug = organization_slug
    @pipeline_slug = pipeline_slug
    @build_number = build_number
    @api_token = api_token
    @base_url = "https://api.buildkite.com/v2/organizations/#{organization_slug}/pipelines/#{pipeline_slug}/builds/#{build_number}/artifacts"
  end

  def call
    all_artifacts = []
    page = 1
    per_page = 100

    loop do
      artifacts = fetch_artifacts_page(page, per_page)

      break if artifacts.empty?

      all_artifacts.concat(artifacts)
      page += 1
    end

    coverage_artifact = all_artifacts.find { |a| a['path'] == 'coverage/index.html' }

    if coverage_artifact
      "https://buildkite.com/organizations/#{@organization_slug}/pipelines/#{@pipeline_slug}/builds/#{@build_number}/jobs/#{coverage_artifact['job_id']}/artifacts/#{coverage_artifact['id']}"
    end
  end

  private

  def fetch_artifacts_page(page, per_page)
    url = "#{@base_url}?per_page=#{per_page}&page=#{page}"
    uri = URI(url)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{@api_token}"

    response = http.request(request)

    if response.code == '200'
      JSON.parse(response.body)
    else
      []
    end
  end
end

# Main execution
if __FILE__ == $0
  # Get environment variables
  organization_slug = ENV['BUILDKITE_ORGANIZATION_SLUG']
  pipeline_slug = ENV['BUILDKITE_PIPELINE_SLUG']
  build_number = ENV['BUILDKITE_BUILD_NUMBER']
  api_token = ENV['ARTIFACT_API_ACCESS_TOKEN']

  if [organization_slug, pipeline_slug, build_number, api_token].any?(&:nil?)
    exit 1
  end

  builder= ReportUrlBuilder.new(organization_slug, pipeline_slug, build_number, api_token)
  report_url = builder.call

  report_url ? puts(report_url) : exit(1)
end
