require 'bundler/setup'
require 'runscope_ci'

include RunscopeCi

# trigger_bucket_and_poll_results(trigger_url, expected_result, interval_sleep=5, retry_limit=60)
res = RunscopeCi::trigger_bucket_and_poll_results("https://api.runscope.com/radar/bucket/c2dff446-8e92-41c7-9bd8-633d7a7a6dcf/trigger", "pass")
puts "res -> #{res}"
