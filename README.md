# AWS Cloud Resume Challenge

This is my attempt at a cloud resume challenge project. The project was published by Forrest Brazeal, and it's a multiple-step resume project which helps build and demonstrate fundamental skills to pursuing a career in Cloud. I came across Rishab Kumar's implementation on the Internet and made my own implementation based on Forrest and Rishab.

## Architecture

![Architecture Diagram](/img/AWS-Architecture-Cloud-resume-challenge.png)


## Requirements
- jq installed (for Makefile)
## Subsequence of installation
- git init -b master
- git lfs track "*.pdf,*.mp3,*.mp4" //In each Git repository where you want to use Git LFS (Github large files support)
- terraform init -backend-config=workspace_key_prefix=aws-cloud-resume-ailves


**Services Used**:

- S3
- AWS CloudFront
- Certificate Manager
- AWS Lambda
- Dynamo DB
- GitHub Actions
- Terraform

## [Live Demo 🔗](https://cv.ailves2009.com)

## Blog Series
- 1. [What is the Cloud Resume Challenge?](https://dev.to/aws-builders/what-is-the-cloud-resume-challenge-ma5)

