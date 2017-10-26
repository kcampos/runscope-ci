FactoryGirl.define do
  factory :rs_test do
    run {
      {
        "status": "init", 
        "environment_id": "3874fh38-340f-034f-fj93-kf8482h7d98h", 
        "bucket_key": "f3984398fj29", 
        "variables": {}, 
        "agent": "some.local.agent", 
        "test_name": "My Perfect Test Case", 
        "test_id": "23cv34c-68d4-4613-b5fc-3453c35v3563", 
        "url": "https://www.runscope.com/radar/f3984398fj29/23cv34c-68d4-4613-b5fc-3453c35v3563/results/2983847f-d23d-23d3-49ie-32988hf38974", 
        "region": nil, 
        "environment_name": "My Shared Environment", 
        "test_url": "https://www.runscope.com/radar/f3984398fj29/23cv34c-68d4-4613-b5fc-3453c35v3563", 
        "test_run_url": "https://www.runscope.com/radar/f3984398fj29/23cv34c-68d4-4613-b5fc-3453c35v3563/results/2983847f-d23d-23d3-49ie-32988hf38974", 
        "test_run_id": "2983847f-d23d-23d3-49ie-32988hf38974"
      }
    }

    initialize_with { new(run) }

    factory :passed_rs_test do
      result "pass"
    end

    factory :failed_rs_test do
      result "fail"
    end

    factory :working_rs_test do
      result "working"
    end
  end
end
