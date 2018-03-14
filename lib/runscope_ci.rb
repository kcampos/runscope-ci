require "runscope_ci/version"
require 'httparty'

module RunscopeCi
  include HTTParty
  base_uri 'api.runscope.com'

  def access_token_name
    "RUNSCOPE_ACCESS_TOKEN"
  end

  def access_token
    ENV[access_token_name]
  end

  def trigger_bucket(trigger_url)
    res = HTTParty.get(trigger_url)
    raise "Received error #{res.code} #{res.message} #{res.body}" unless res.code == 201
    puts "Triggered test bucket url -> #{trigger_url}"
    JSON.parse(res.body)
  end

  def extract_tests(response_data)
    response_data["data"]["runs"].collect { |run| RunscopeCi::RsTest.new(run) }
  end

  def trigger_bucket_and_poll_results(trigger_url, expected_result, interval_sleep=5, retry_limit=60)
    tests = extract_tests(trigger_bucket(trigger_url))
    attempt = 1
    
    until ( tests.collect {|t| t.result_detail }.select{|rs_test| rs_test.result == "working"}.empty? )
      puts "Waiting for tests to finish working, attempt #{attempt}"
      raise("Timed out waiting for results, tests still 'working'") if attempt > retry_limit
      sleep interval_sleep
      attempt += 1
    end

    all_tests_have_result?(expected_result, tests)
  end

  def all_tests_have_result?(expected_result, tests)
    unless tests.all?{|t| t.result == expected_result}
      puts "Tests finished working. Bucket returned unexpected test results:"
      tests.select{|t| t.result != "#{expected_result}"}.each do |t|
        puts "#{t.test_name}: #{t.result} - #{t.url}"
      end
      raise("Unexpected test results")
    else
      return "Tests finished working. Success! All results were: #{expected_result}"
    end
  end

  class RsTest
    include HTTParty
    base_uri 'api.runscope.com'

    attr_reader :status, :environment_id, :bucket_key, :variables, :agent, :test_name, :test_id, :url,
      :region, :environment_name, :test_url, :test_run_url, :test_run_id, :started_at, :finished_at,
      :scripts_defined, :assertions_failed, :variables_failed, :variables_passed, :requests_executed,
      :assertions_defined, :assertions_passed, :scripts_passed, :scripts_failed, :variables_defined, :requests
    attr_accessor :result

    # expects parsed json 'run' block from Runscope API response like trigger bucket call
    def initialize(run)
      @status           = run["status"]
      @environment_id   = run["environment_id"]
      @bucket_key       = run["bucket_key"]
      @variables        = run["variables"]
      @agent            = run["agent"]
      @test_name        = run["test_name"]
      @test_id          = run["test_id"]
      @url              = run["url"]
      @region           = run["region"]
      @environment_name = run["environment_name"]
      @test_url         = run["test_url"]
      @test_run_url     = run["test_run_url"]
      @test_run_id      = run["test_run_id"]
    end

    def result_detail 
      res = self.class.get("/buckets/#{@bucket_key}/tests/#{@test_id}/results/#{@test_run_id}",
        headers: {"Authorization" => "Bearer #{access_token}"})
      raise "Received error #{res.code} #{res.message} #{res.body}" unless res.code == 200
      result = JSON.parse(res.body)["data"]
      
      @started_at         = result["started_at"]
      @finished_at        = result["finished_at"]
      @scripts_defined    = result["scripts_defined"]
      @assertions_failed  = result["assertions_failed"]
      @variables_failed   = result["variables_failed"]
      @variables_passed   = result["variables_passed"]
      @result             = result["result"]
      @requests_executed  = result["requests_executed"]
      @assertions_defined = result["assertions_defined"]
      @assertions_passed  = result["assertions_passed"]
      @scripts_passed     = result["scripts_passed"]
      @scripts_failed     = result["scripts_failed"]
      @variables_defined  = result["variables_defined"]
      @requests           = result["requests"]

      self
    end
  end
end
