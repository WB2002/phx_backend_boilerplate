# Narrow Dialyzer suppressions — each entry documents a known false positive or upstream typespec issue.
[
  # ExAws.CloudWatchLogs.put_log_events/4 declares the log_events argument as binary() in its
  # @spec, but the implementation and AWS API expect a list of event maps.
  {"lib/phx_backend_boilerplate/observability/cloudwatch_logs_client/ex_aws.ex",
   :callback_arg_type_mismatch}
]
