require 'spec_helper'
include RunscopeCi

describe RunscopeCi do
  let(:httparty_obj) { double("HTTParty") }
  let(:access_token) { 'my-access-token' }

  before(:each) { allow(ENV).to receive(:[]).with('RUNSCOPE_ACCESS_TOKEN') { access_token } }

  it 'has a version number' do
    expect(RunscopeCi::VERSION).not_to be nil
  end

  it "has an access token name" do
    expect(RunscopeCi::access_token_name).to eql("RUNSCOPE_ACCESS_TOKEN")
  end

  it 'has an access_token' do
    expect(RunscopeCi::access_token).to eql(access_token)
  end

  describe "#trigger_bucket" do
    before do
      allow(httparty_obj).to receive(:body) { result_detail_data }
      allow(httparty_obj).to receive(:code) { http_response_code }
      allow(httparty_obj).to receive(:message) { http_message }
    end

    it "should require a trigger url" do
      expect {RunscopeCi::trigger_bucket}.to raise_error(ArgumentError)
    end

    context "when a trigger url is passed" do
      let(:trigger_url) { "https://api.runscope.com/radar/bucket/2d87h8273-f343-3f3y-g563-f3jh9847h847hy/trigger" }
      
      before(:each) do
        expect(HTTParty).to receive(:get).with(trigger_url) { httparty_obj }
      end

      context "and API request is successful" do
        let(:http_response_code) { 201 }
        let(:result_detail_data) {
          {
            "meta": {
              "status": "success"
            },
            "data": {
              "runs_started": 13,
              "runs": [
                {
                  "status": "init",
                  "environment_id": "3874fh38-340f-034f-fj93-kf8482h7d98h",
                  "bucket_key": "f3984398fj29",
                  "variables": {},
                  "agent": "My Test Agent",
                  "test_name": "My Test Name",
                  "test_id": "3434f3s-3f3g-g43f-34gj-9384fh938u",
                  "url": "https://www.runscope.com/radar/f3984398fj29/2d87h8273-f343-3f3y-g563-f3jh9847h847hy/results/8327hf-2f928rf-28rfj2984fj-24f2f",
                  "region": nil,
                  "environment_name": "My Shared Environment",
                  "test_url": "https://www.runscope.com/radar/f3984398fj29/2d87h8273-f343-3f3y-g563-f3jh9847h847hy",
                  "test_run_url": "https://www.runscope.com/radar/f3984398fj29/2d87h8273-f343-3f3y-g563-f3jh9847h847hy/results/8327hf-2f928rf-28rfj2984fj-24f2f",
                  "test_run_id": "782c37dd-d33f-4025-9f8d-073b31f2f2b5"
                }
              ]
            }
          }.to_json
        }

        it "should return JSON parsed api response" do
          expect(RunscopeCi::trigger_bucket(trigger_url).to_json).to eql(result_detail_data)
        end
      end
    end
  end

  describe "#trigger_bucket_and_poll_results" do
    let(:trigger_url) { "https://api.runscope.com/radar/bucket/f384975hf9387f/trigger" }
    let(:trigger_bucket_data) { double("TriggerBucketData") }
    let(:passed_test_1)  { FactoryBot.build :passed_rs_test }
    let(:passed_test_2)  { FactoryBot.build :passed_rs_test }
    let(:failed_test_1)  { FactoryBot.build :failed_rs_test }
    let(:working_test_1) { FactoryBot.build :working_rs_test }
    let(:extracted_tests) { [passed_test_1, passed_test_2, failed_test_1, working_test_1] }
    let(:expected_result) { "pass" }
    let(:interval_sleep) { 0 }
    let(:retry_limit) { 5 }

    subject { RunscopeCi::trigger_bucket_and_poll_results(trigger_url, expected_result, interval_sleep, retry_limit) }

    before(:each) do
      allow(RunscopeCi).to receive(:trigger_bucket).with(trigger_url) { trigger_bucket_data }
      allow(RunscopeCi).to receive(:extract_tests).with(trigger_bucket_data) { extracted_tests }
      allow(passed_test_1).to receive(:result_detail) { passed_test_1 }
      allow(passed_test_2).to receive(:result_detail) { passed_test_2 }
      allow(failed_test_1).to receive(:result_detail) { failed_test_1 }
      allow(working_test_1).to receive(:result_detail) { working_test_1 }
    end

    context "when no tests are left in working state" do
      context "and test results are mixed" do
        let(:extracted_tests) { [passed_test_1, passed_test_2, failed_test_1] }

        context "and we expected all to pass" do
          it { is_expected.to eql([false, extracted_tests]) }
        end
      end

      context "and test results are all pass" do
        let(:extracted_tests) { [passed_test_1, passed_test_2] }

        context "and we expected all to pass" do
          it { is_expected.to eql([true, extracted_tests]) }
        end

        context "and we expected all to fail" do
          let(:expected_result) { "fail" }

          it { is_expected.to eql([false, extracted_tests]) }
        end
      end

      context "and test results are all fail" do
        let(:extracted_tests) { [failed_test_1] }

        context "and we expected all to fail" do
          let(:expected_result) { "fail" }

          it { is_expected.to eql([true, extracted_tests]) }
        end

        context "and we expected all to pass" do
          it { is_expected.to eql([false, extracted_tests]) }
        end
      end
    end

    context "when tests are left in working state" do
      let(:extracted_tests) { [passed_test_1, passed_test_2, failed_test_1, working_test_1] }

      it { expect{subject}.to raise_error("Timed out waiting for results, tests still 'working'") }
    end
  end

  describe "#extract_tests" do
    let(:trigger_bucket_data) {
      {
        "meta" => {
          "status" => "success"
        },
        "data" => {
          "runs_started" => 2,
          "runs" => [
            {
              "status" => "init",
              "environment_id" => "3874fh38-340f-034f-fj93-kf8482h7d98h",
              "bucket_key" => "f3984398fj29",
              "variables" => {},
              "agent" => "My Test Agent",
              "test_name" => "My Test Name",
              "test_id" => "3434f3s-3f3g-g43f-34gj-9384fh938u",
              "url" => "https://www.runscope.com/radar/f3984398fj29/2d87h8273-f343-3f3y-g563-f3jh9847h847hy/results/8327hf-2f928rf-28rfj2984fj-24f2f",
              "region" => nil,
              "environment_name" => "My Shared Environment",
              "test_url" => "https://www.runscope.com/radar/f3984398fj29/2d87h8273-f343-3f3y-g563-f3jh9847h847hy",
              "test_run_url" => "https://www.runscope.com/radar/f3984398fj29/2d87h8273-f343-3f3y-g563-f3jh9847h847hy/results/8327hf-2f928rf-28rfj2984fj-24f2f",
              "test_run_id" => "782c37dd-d33f-4025-9f8d-073b31f2f2b5"
            },
            {
              "status" => "init",
              "environment_id" => "3874fh38-340f-034f-fj93-33453gg3g3",
              "bucket_key" => "g345g345g3g3",
              "variables" => {},
              "agent" => "My Test Agent",
              "test_name" => "My 2nd Test Name",
              "test_id" => "3434f3s-3f3g-g43f-34gj-g345g33",
              "url" => "https://www.runscope.com/radar/354g345g34345g/345g345g345g-f343-3f3y-g563-f3jh9847h847hy/results/345g34g-2f928rf-28rfj2984fj-24f2f",
              "region" => nil,
              "environment_name" => "My Shared Environment",
              "test_url" => "https://www.runscope.com/radar/345g345g/345g345g-f343-3f3y-g563-f3jh9847h847hy",
              "test_run_url" => "https://www.runscope.com/radar/345g343/345g345g-f343-3f3y-g563-f3jh9847h847hy/results/345g345g-2f928rf-28rfj2984fj-24f2f",
              "test_run_id" => "345g345g3-d33f-4025-9f8d-f234ffr"
            }
          ],
          "runs_failed" => 0,
          "runs_total" => 2
        },
        "error" => nil
      }
    }

    it "should return array of tests" do
      expect(extract_tests(trigger_bucket_data)).to be_a_kind_of(Array)
      expect(extract_tests(trigger_bucket_data).first.test_run_id).to eql("782c37dd-d33f-4025-9f8d-073b31f2f2b5")
      expect(extract_tests(trigger_bucket_data).last.test_run_id).to eql("345g345g3-d33f-4025-9f8d-f234ffr")
    end
  end

  describe RunscopeCi::RsTest do
    let(:run_data) {
      {
        "status" => "init", 
        "environment_id" => "3874fh38-340f-034f-fj93-kf8482h7d98h", 
        "bucket_key" => "f3984398fj29", 
        "variables" => {}, 
        "agent" => "some.local.agent", 
        "test_name" => "My Perfect Test Case", 
        "test_id" => "23cv34c-68d4-4613-b5fc-3453c35v3563", 
        "url" => "https://www.runscope.com/radar/f3984398fj29/23cv34c-68d4-4613-b5fc-3453c35v3563/results/2983847f-d23d-23d3-49ie-32988hf38974", 
        "region" => nil, 
        "environment_name" => "My Shared Environment", 
        "test_url" => "https://www.runscope.com/radar/f3984398fj29/23cv34c-68d4-4613-b5fc-3453c35v3563", 
        "test_run_url" => "https://www.runscope.com/radar/f3984398fj29/23cv34c-68d4-4613-b5fc-3453c35v3563/results/2983847f-d23d-23d3-49ie-32988hf38974", 
        "test_run_id" => "2983847f-d23d-23d3-49ie-32988hf38974"
      }
    }

    let(:unfinished_result_detail_data) {
      {
        "meta": {
            "status": "success"
        },
        "data": {
            "started_at": 1485460015.527726,
            "scripts_defined": 0,
            "environment_id": "3874fh38-340f-034f-fj93-kf8482h7d98h",
            "bucket_key": "f3984398fj29",
            "finished_at": nil,
            "assertions_failed": 0,
            "agent": "some.local.agent",
            "variables_failed": 0,
            "result": "working",
            "variables_passed": 0,
            "test_id": "23cv34c-68d4-4613-b5fc-3453c35v3563",
            "requests_executed": 0,
            "assertions_defined": 0,
            "assertions_passed": 0,
            "scripts_passed": 0,
            "scripts_failed": 0,
            "environment_name": "My Shared Environment",
            "test_run_url": "https://www.runscope.com/radar/f3984398fj29/23cv34c-68d4-4613-b5fc-3453c35v3563/results/2983847f-d23d-23d3-49ie-32988hf38974",
            "test_run_id": "2983847f-d23d-23d3-49ie-32988hf38974",
            "variables_defined": 0,
            "requests": [
                {
                    "scripts_defined": nil,
                    "assertions_passed": nil,
                    "uuid": "sdf334fg-6234-4f3w-454g-hf8374h87hg7",
                    "scripts_failed": nil,
                    "url": nil,
                    "variables": nil,
                    "assertions_failed": nil,
                    "scripts_passed": nil,
                    "variables_failed": nil,
                    "result": nil,
                    "variables_passed": nil,
                    "scripts": nil,
                    "variables_defined": nil,
                    "assertions_defined": nil,
                    "method": nil,
                    "assertions": nil
                }
            ],
            "region": nil
        },
        "error": nil
      }.to_json
    }

    let(:finished_result_detail_data) {
      {
        "meta": {
            "status": "success"
        },
        "data": {
            "started_at": 1485460015.527726,
            "scripts_defined": 0,
            "environment_id": "3874fh38-340f-034f-fj93-kf8482h7d98h",
            "bucket_key": "f3984398fj29",
            "finished_at": 1485460040.414293,
            "assertions_failed": 0,
            "agent": "some.local.agent",
            "variables_failed": 0,
            "result": "pass",
            "variables_passed": 0,
            "test_id": "23cv34c-68d4-4613-b5fc-3453c35v3563",
            "requests_executed": 1,
            "assertions_defined": 2,
            "assertions_passed": 2,
            "scripts_passed": 0,
            "scripts_failed": 0,
            "environment_name": "My Shared Environment",
            "test_run_url": "https://www.runscope.com/radar/f3984398fj29/23cv34c-68d4-4613-b5fc-3453c35v3563/results/2983847f-d23d-23d3-49ie-32988hf38974",
            "test_run_id": "2983847f-d23d-23d3-49ie-32988hf38974",
            "variables_defined": 0,
            "requests": [
                {
                    "scripts_defined": nil,
                    "assertions_passed": nil,
                    "uuid": "sdf334fg-6234-4f3w-454g-hf8374h87hg7",
                    "scripts_failed": nil,
                    "url": nil,
                    "variables": nil,
                    "assertions_failed": nil,
                    "scripts_passed": nil,
                    "variables_failed": nil,
                    "result": nil,
                    "variables_passed": nil,
                    "scripts": nil,
                    "variables_defined": nil,
                    "assertions_defined": nil,
                    "method": nil,
                    "assertions": nil
                }
            ],
            "region": nil
        },
        "error": nil
      }.to_json
    }

    describe "#initialize" do
      subject(:rs_test) { RunscopeCi::RsTest.new(run_data) }

      context "with valid run_data passed" do
        it { expect(rs_test.status).to eql("init") }
        it { expect(rs_test.environment_id).to eql("3874fh38-340f-034f-fj93-kf8482h7d98h") }
        it { expect(rs_test.bucket_key).to eql("f3984398fj29") }
        it { expect(rs_test.variables).to be_a_kind_of(Hash) }
        it { expect(rs_test.agent).to eql("some.local.agent") }
        it { expect(rs_test.test_name).to eql("My Perfect Test Case") }
        it { expect(rs_test.test_id).to eql("23cv34c-68d4-4613-b5fc-3453c35v3563") }
        it { expect(rs_test.url).to eql("https://www.runscope.com/radar/f3984398fj29/23cv34c-68d4-4613-b5fc-3453c35v3563/results/2983847f-d23d-23d3-49ie-32988hf38974") }
        it { expect(rs_test.region).to be nil }
        it { expect(rs_test.environment_name).to eql("My Shared Environment") }
        it { expect(rs_test.test_url).to eql("https://www.runscope.com/radar/f3984398fj29/23cv34c-68d4-4613-b5fc-3453c35v3563") }
        it { expect(rs_test.test_run_url).to eql("https://www.runscope.com/radar/f3984398fj29/23cv34c-68d4-4613-b5fc-3453c35v3563/results/2983847f-d23d-23d3-49ie-32988hf38974") }
        it { expect(rs_test.test_run_id).to eql("2983847f-d23d-23d3-49ie-32988hf38974") }
        it { expect(rs_test.started_at).to be nil }
        it { expect(rs_test.finished_at).to be nil }
        it { expect(rs_test.scripts_defined).to be nil }
        it { expect(rs_test.assertions_failed).to be nil }
        it { expect(rs_test.variables_failed).to be nil }
        it { expect(rs_test.variables_passed).to be nil }
        it { expect(rs_test.result).to be nil }
        it { expect(rs_test.requests_executed).to be nil }
        it { expect(rs_test.assertions_defined).to be nil }
        it { expect(rs_test.assertions_passed).to be nil }
        it { expect(rs_test.scripts_passed).to be nil }
        it { expect(rs_test.scripts_failed).to be nil }
        it { expect(rs_test.variables_defined).to be nil }
        it { expect(rs_test.requests).to be nil }
      end
    end

    describe "#result_detail" do
      let(:rs_test) { RunscopeCi::RsTest.new(run_data) }
      let(:http_response_code) { 200 }
      let(:http_message) { "" }

      subject(:result_detail) { rs_test.result_detail }

      before(:each) do
        allow(httparty_obj).to receive(:body) { result_detail_data }
        allow(httparty_obj).to receive(:code) { http_response_code }
        allow(httparty_obj).to receive(:message) { http_message }
        allow(rs_test).to receive_message_chain(:class, :get).with(
          "/buckets/#{rs_test.bucket_key}/tests/#{rs_test.test_id}/results/#{rs_test.test_run_id}",  {:headers=>{"Authorization"=>"Bearer #{access_token}"}}) { httparty_obj }
      end

      context "when runscope API call succeeds" do
        context "and when test run is not complete" do
          let(:result_detail_data) { unfinished_result_detail_data }

          it { expect(result_detail.started_at).to eql(1485460015.527726) }
          it { expect(result_detail.finished_at).to be nil }
          it { expect(result_detail.assertions_failed).to eql(0) }
          it { expect(result_detail.variables_failed).to eql(0) }
          it { expect(result_detail.variables_passed).to eql(0) }
          it { expect(result_detail.result).to eql("working") }
          it { expect(result_detail.requests_executed).to eql(0) }
          it { expect(result_detail.assertions_defined).to eql(0) }
          it { expect(result_detail.assertions_passed).to eql(0) }
          it { expect(result_detail.scripts_passed).to eql(0) }
          it { expect(result_detail.scripts_failed).to eql(0) }
          it { expect(result_detail.variables_defined).to eql(0) }
          it { expect(result_detail.requests).to be_a_kind_of(Array) }
        end

        context "and when test run is complete" do
          let(:result_detail_data) { finished_result_detail_data }

          it { expect(result_detail.started_at).to eql(1485460015.527726) }
          it { expect(result_detail.finished_at).to eql(1485460040.414293) }
          it { expect(result_detail.assertions_failed).to eql(0) }
          it { expect(result_detail.variables_failed).to eql(0) }
          it { expect(result_detail.variables_passed).to eql(0) }
          it { expect(result_detail.result).to eql("pass") }
          it { expect(result_detail.requests_executed).to eql(1) }
          it { expect(result_detail.assertions_defined).to eql(2) }
          it { expect(result_detail.assertions_passed).to eql(2) }
          it { expect(result_detail.scripts_passed).to eql(0) }
          it { expect(result_detail.scripts_failed).to eql(0) }
          it { expect(result_detail.variables_defined).to eql(0) }
          it { expect(result_detail.requests).to be_a_kind_of(Array) }
        end
      end

      context "when runscope API call fails" do
        let(:http_response_code) { 404 }
        let(:http_message) { "Service Unavailable" }
        let(:result_detail_data) { "tis broke" }

        it  { expect{result_detail}.to raise_error("Received error #{http_response_code} #{http_message} #{result_detail_data}") }
      end
    end
  end
end