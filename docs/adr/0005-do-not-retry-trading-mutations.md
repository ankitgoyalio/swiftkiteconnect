# Do not automatically retry trading mutations

If a trading mutation loses its response, the server may already have accepted it. The SDK will not automatically resubmit trading mutations, avoiding duplicate actions at the cost of requiring caller-owned reconciliation.

Transport failures will be distinguishable from confirmed API rejections, and failures after a request may have been sent must communicate the uncertain outcome. The first release sends each REST request once, including read requests, with configurable timeouts. Rate-limit errors are exposed to callers; automatic retries and request queuing are deferred, leaving scheduling and reconciliation to the application.
