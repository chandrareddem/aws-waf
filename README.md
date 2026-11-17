# AWS WAF managed with GitHub Actions

This repository creates a **regional AWS WAF Web ACL** with Terraform. It starts with AWS's `AWSManagedRulesCommonRuleSet` managed rule group in **Count** mode. The ACL's default action is Allow, so requests are monitored but not blocked by this initial configuration. The ACL is not associated with a protected resource.

The workflow validates Terraform on pull requests. A push to `main` or `master` applies the configuration; you can also run it manually from either branch with **Actions → Deploy AWS WAF → Run workflow**.

## One-time AWS setup

The workflow uses GitHub's OIDC identity to assume an AWS IAM role. It does not use long-lived AWS access keys. Do these bootstrap steps once, using an administrator or infrastructure-provisioning process:

1. **Create a Terraform state S3 bucket** in the AWS region you will use. Choose a globally unique bucket name. Enable bucket versioning, default encryption, and all S3 Block Public Access settings. The workflow uses S3's native state lock file, so Terraform 1.10 or later is required.
2. **Configure GitHub's OIDC identity provider** in AWS IAM if your account does not already have it:
   - Provider URL: `https://token.actions.githubusercontent.com`
   - Audience: `sts.amazonaws.com`
3. **Create an IAM role for GitHub Actions** with a trust policy restricted to your repository's `production` GitHub environment. Because the workflow uses that environment, the OIDC subject contains the environment name rather than the branch name. Replace `OWNER/REPOSITORY`:

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": {
           "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
         },
         "Action": "sts:AssumeRoleWithWebIdentity",
         "Condition": {
           "StringEquals": {
             "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
             "token.actions.githubusercontent.com:sub": "repo:OWNER/REPOSITORY:environment:production"
           }
         }
       }
     ]
   }
   ```

4. Attach a permissions policy to that role. Replace the uppercase placeholders. The WAF read/update/tag actions are scoped to Web ACLs in this account and region; create/list/capacity-check operations use `"Resource": "*"`. The S3 permissions are scoped to this repository's state and lock files.

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "wafv2:CreateWebACL",
           "wafv2:ListWebACLs",
           "wafv2:CheckCapacity",
           "wafv2:ListAvailableManagedRuleGroups"
         ],
         "Resource": "*"
       },
       {
         "Effect": "Allow",
         "Action": [
           "wafv2:GetWebACL",
           "wafv2:UpdateWebACL",
           "wafv2:DeleteWebACL",
           "wafv2:TagResource",
           "wafv2:UntagResource",
           "wafv2:ListTagsForResource"
         ],
         "Resource": "arn:aws:wafv2:AWS_REGION:ACCOUNT_ID:regional/webacl/*/*"
       },
       {
         "Effect": "Allow",
         "Action": "s3:ListBucket",
         "Resource": "arn:aws:s3:::STATE_BUCKET",
         "Condition": {
           "StringLike": {
             "s3:prefix": [
               "aws-waf/OWNER/REPOSITORY.tfstate",
               "aws-waf/OWNER/REPOSITORY.tfstate.tflock"
             ]
           }
         }
       },
       {
         "Effect": "Allow",
         "Action": [
           "s3:GetObject",
           "s3:PutObject"
         ],
         "Resource": "arn:aws:s3:::STATE_BUCKET/aws-waf/OWNER/REPOSITORY.tfstate"
       },
       {
         "Effect": "Allow",
         "Action": [
           "s3:GetObject",
           "s3:PutObject",
           "s3:DeleteObject"
         ],
         "Resource": "arn:aws:s3:::STATE_BUCKET/aws-waf/OWNER/REPOSITORY.tfstate.tflock"
       }
     ]
   }
   ```

   Check the AWS Service Authorization Reference if your account or provider version requires additional WAF actions.

## GitHub repository configuration

In **Settings → Secrets and variables → Actions**, add:

| Name | Type | Value |
| --- | --- | --- |
| `AWS_ROLE_ARN` | Secret | ARN of the IAM role created above |
| `AWS_REGION` | Variable | AWS region for the regional Web ACL and state bucket |
| `TF_STATE_BUCKET` | Variable | Name of the versioned Terraform state bucket |

In **Settings → Environments**, create an environment named `production` and restrict its deployment branches to `main` and/or `master`, matching the branch you use. Optionally configure required reviewers to approve deployments before Terraform applies changes.

## Deployment and next steps

Merge the configuration to `main` or `master`, or manually run the workflow on either branch. The resulting Web ACL ARN is available in the Terraform outputs and the workflow logs.

The ACL is deliberately created without an association. Review the sampled requests and CloudWatch metrics first. When ready, change the rule group's `override_action` from `count {}` to `none {}` to allow its managed rules to enforce their configured actions, then associate the Web ACL with your regional resource. Test rule changes in a non-production environment where possible; managed rules can block legitimate traffic after enforcement is enabled.

This repository configures only the Web ACL. It does not create an ALB/API, logging destination, or association.
