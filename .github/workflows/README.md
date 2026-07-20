# Benchmark automation

These workflows launch benchmark machines on AWS. The GitHub-hosted runner is
used only to launch: it assumes a federated IAM role and runs
`run-benchmark.sh`, which starts a self-terminating EC2 machine. The machine
clones the repository, runs `<system>/benchmark.sh` under cloud-init (see
`cloud-init.sh.in`), sends its log to the results sink at play.clickhouse.com,
and shuts down. Collecting the results back into `<system>/results/` is a
separate process, implemented separately.

| Workflow | Trigger | What it launches |
|----------|---------|------------------|
| `benchmark-daily.yml` | daily, 02:00 UTC | the ClickHouse variants on c6a.4xlarge from main |
| `benchmark-manual.yml` | manual | any system, machine, repository and branch |
| `benchmark-pr.yml` | pull requests | the systems whose directories the PR changes (results and *.md files don't count), from the PR's repository and branch, after manual approval |

## Setup

1. An IAM role for GitHub's OIDC provider, restricted to this repository:

   ```json
   {
       "Version": "2012-10-17",
       "Statement": [{
           "Effect": "Allow",
           "Principal": { "Federated": "arn:aws:iam::<account>:oidc-provider/token.actions.githubusercontent.com" },
           "Action": "sts:AssumeRoleWithWebIdentity",
           "Condition": {
               "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
               "StringLike": { "token.actions.githubusercontent.com:sub": "repo:ClickHouse/ClickBench:*" }
           }
       }]
   }
   ```

   The permissions policy needs `ec2:RunInstances`, `ec2:CreateTags`,
   `ec2:DescribeImages`, and `ec2:DescribeInstanceTypes`.

2. Repository variables `BENCHMARK_AWS_ROLE_ARN` (the ARN of that role) and
   `BENCHMARK_AWS_REGION`. While the variables are not set, the workflows
   skip the launch instead of failing.

3. An environment named `benchmark-approval` with required reviewers. It
   gates the PR workflow: nothing is launched for a pull request until a
   reviewer approves the pending deployment.

4. Enough on-demand vCPU quota in the region: the daily run launches six
   c6a.4xlarge machines at once, 96 vCPUs, on top of whatever is still
   running. `run-benchmark.sh` waits and retries while the quota is
   exhausted, but only within the job's 55-minute limit.
