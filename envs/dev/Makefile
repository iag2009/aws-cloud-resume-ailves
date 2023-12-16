SHELL = /bin/bash
ACCOUNT := $(shell cat inputs.dev.tfvars.json | jq -r .aws_account)
REGION := $(shell cat inputs.dev.tfvars.json | jq -r .region)
PROJECT := $(shell cat inputs.dev.tfvars.json | jq -r .project)
ENV := $(shell cat inputs.dev.tfvars.json | jq -r .environment)

.PHONY: init
init:
	# rm -rf .terraform
	terraform init -backend-config=workspace_key_prefix="${PROJECT}/${ACCOUNT}"
	terraform workspace select "${ENV}" || terraform workspace new "${ENV}"

.PHONY: terraform
terraform: init
	terraform ${ACTION} -var-file=inputs.dev.tfvars.json

plan:
	ACTION=$@ $(MAKE) terraform

apply:
	ACTION=$@ $(MAKE) terraform

destroy:
	ACTION=$@ $(MAKE) terraform
