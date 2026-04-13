# Defaults (override with env vars, e.g. make build PROJECT_ID=my-proj)
PROJECT_ID ?= gamma4-fine-tuning
REGION ?= us-central1
REPO ?= ml-containers
IMAGE ?= vertex-test
TAG ?= v1
IMAGE_URI ?= $(REGION)-docker.pkg.dev/$(PROJECT_ID)/$(REPO)/$(IMAGE):$(TAG)
VM_NAME ?= ft-vm
ZONE ?= us-central1-a
USER ?= $(shell whoami)
JOB_ID ?=
LOCAL_BUILD_DIR ?= .
LOCAL_RUN_NAME ?= ft_container

ROOT_DIR := ..
COMPUTE_SCRIPTS := $(ROOT_DIR)/google-cloud-compute-ml/scripts
CONTAINER_SCRIPTS := $(ROOT_DIR)/container-engineering/scripts
JOB_SCRIPTS := $(ROOT_DIR)/cloud-job-orchestration/scripts
STATUS_FILE := $(ROOT_DIR)/status.md

.PHONY: help list-repos list-images build build-script push pull run-local run-detached logs-docker \
	vm-create vm-ssh vm-transfer vm-run submit-job stream-job-logs status-file use-skills check-vm-status all

help:
	@printf "Targets:\n  list-repos list-images build build-script push pull run-local run-detached logs-docker\n  vm-create vm-ssh vm-transfer vm-run submit-job stream-job-logs status-file use-skills check-vm-status\n\nEnvironment overrides: PROJECT_ID REGION REPO IMAGE TAG IMAGE_URI VM_NAME ZONE USER JOB_ID LOCAL_BUILD_DIR\nExample: make build PROJECT_ID=foo REGION=us-central1\n"

use-skills:
	@ls -la /home/avreymi/code/dotfiles/skills || true

list-repos:
	gcloud artifacts repositories list --project="$(PROJECT_ID)" --format="table(name, format, location)"

list-images:
	gcloud artifacts docker images list $(REGION)-docker.pkg.dev/$(PROJECT_ID)/$(REPO) --include-tags --format="table(IMAGE, TAGS, UPDATE_TIME)"

build:
	@echo "docker build -t $(IMAGE_URI) in $(LOCAL_BUILD_DIR)"
	cd $(LOCAL_BUILD_DIR) && docker build -t $(IMAGE_URI) .

build-script:
	chmod +x $(CONTAINER_SCRIPTS)/build-and-push.sh || true
	$(CONTAINER_SCRIPTS)/build-and-push.sh "$(TAG)"

push:
	docker push $(IMAGE_URI)

pull:
	docker pull $(IMAGE_URI)

run-local:
	docker pull $(IMAGE_URI) || true
	docker run --gpus all --rm -it $(IMAGE_URI) /bin/bash

run-detached:
	docker pull $(IMAGE_URI) || true
	docker run --gpus all -d --name $(LOCAL_RUN_NAME) -p 8080:8080 -e PROJECT=$(PROJECT_ID) $(IMAGE_URI)

logs-docker:
	docker logs -f $(LOCAL_RUN_NAME)

vm-create:
	chmod +x $(COMPUTE_SCRIPTS)/gcp_compute.sh || true
	$(COMPUTE_SCRIPTS)/gcp_compute.sh create --name "$(VM_NAME)" --zone "$(ZONE)" --project "$(PROJECT_ID)"

vm-ssh:
	chmod +x $(COMPUTE_SCRIPTS)/gcp_ssh.sh || true
	$(COMPUTE_SCRIPTS)/gcp_ssh.sh "$(VM_NAME)" --zone "$(ZONE)" --project "$(PROJECT_ID)"

vm-transfer:
	chmod +x $(COMPUTE_SCRIPTS)/gcp_transfer.sh || true
	@if [ -z "$(FILE)" ]; then echo "Set FILE=path/to/local"; exit 1; fi
	@if [ -z "$(REMOTE_PATH)" ]; then echo "Set REMOTE_PATH=/home/$(USER)/dest"; exit 1; fi
	$(COMPUTE_SCRIPTS)/gcp_transfer.sh upload "$(FILE)" "$(VM_NAME):$(REMOTE_PATH)" --zone "$(ZONE)" --project "$(PROJECT_ID)"

vm-run:
	@echo "Pulling and running $(IMAGE_URI) on $(VM_NAME)"
	ssh_cmd="sudo docker pull $(IMAGE_URI) && sudo docker rm -f $(LOCAL_RUN_NAME) >/dev/null 2>&1 || true && sudo docker run --gpus all -d --name $(LOCAL_RUN_NAME) -p 8080:8080 $(IMAGE_URI) && sudo docker logs -f $(LOCAL_RUN_NAME)"; \
	$(COMPUTE_SCRIPTS)/gcp_ssh.sh "$(VM_NAME)" --zone "$(ZONE)" --project "$(PROJECT_ID)" --command "$$ssh_cmd"

check-vm-status:
	chmod +x $(COMPUTE_SCRIPTS)/gcp_compute.sh || true
	$(COMPUTE_SCRIPTS)/gcp_compute.sh status --name "$(VM_NAME)" --zone "$(ZONE)" --project "$(PROJECT_ID)"

submit-job:
	python3 $(JOB_SCRIPTS)/submit-training-job.py \
		--project "$(PROJECT_ID)" --region "$(REGION)" \
		--image-uri "$(IMAGE_URI)" \
		--worker-pool-spec "machineType=n1-standard-4,accelerator-type=NVIDIA_TESLA_T4,accelerator-count=1"

stream-job-logs:
	@if [ -z "$(JOB_ID)" ]; then echo "Set JOB_ID=your-job-id"; exit 1; fi
	gcloud ai custom-jobs stream-logs $(JOB_ID) --region=$(REGION) --project=$(PROJECT_ID)

status-file:
	cat $(STATUS_FILE) || true

all: build push
	@echo "Built and pushed $(IMAGE_URI)"