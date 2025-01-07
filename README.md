# green-bird

Terraform/AWS practice project. Spins up:
- API Gateway with custom domain
- Cognito User Pool & Client
- Login page that redirects to Cognito-hosted authentication
- Cognito callback to set auth tokens (Lambda/Python)
- Simple protected endpoint (Lambda/Python)

## Prerequisites

- AWS account with owner privs
- A top-level domain pointed to AWS DNS (e.g. `yourdomain.com`)
- AWS ACM Certificates in `us-east-1` and `us-west-1` (for `yourdomain.com` and `*.yourdomain.com`)
- AWS Route53 Hosted Zone (for `yourdomain.com`)

## Hints

- Cognito user pool starts out with 0 users. Use the console to create a user.
- Then go to https://www.example.com/login.html


