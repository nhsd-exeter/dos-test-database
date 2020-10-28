PROJECT_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
include $(abspath $(PROJECT_DIR)/build/automation/init.mk)

# ==============================================================================
# Development workflow targets

download: project-config # Download DoS database dump file
	[ -f build/docker/data/assets/data/50-dos-database-dump.sql.gz ] && exit 0
	eval $$(make aws-assume-role-export-variables)
	make aws-s3-download \
		URI=nhsd-texasplatform-service-dos-lk8s-nonprod/dos-pg-dump-$(DOS_DATABASE_VERSION)-clean-PU.sql.gz \
		FILE=build/docker/data/assets/data/50-dos-database-dump.sql.gz
	make _fix

_fix:
	cd build/docker/data/assets/data
	gunzip 50-dos-database-dump.sql.gz
	sed -i "s/SET default_tablespace = pathwaysdos_index_01;//g" 50-dos-database-dump.sql
	gzip 50-dos-database-dump.sql

build: project-config # Build DoS database image
	make docker-build NAME=data

start: # Start service locally
	docker volume rm --force "data" 2> /dev/null ||:
	docker volume create --name "data"
	make project-start

stop: # Stop service locally
	make project-stop
	docker volume rm --force "data" 2> /dev/null ||:

log: project-log # Print service logs

# --------------------------------------

image: # Create data and database images from the dump file and push them to the registry
	make \
		image-create \
		image-test \
		image-push

instance: # Create an instance and populate it from the existing data image - optional: VERSION=[version or tag of the data image, defaults to the just built image],NAME=[instance name, defaults to "test"]
	make \
		instance-create \
		instance-populate

clean: # Remove all the resources - optional: NAME=[instance name, defaults to "test"]
	rm -fv build/docker/data/assets/data/*.sql.gz
	rm -rf $(TMP_DIR)/*
	make k8s-undeploy-job \
		STACK=data \
		PROFILE=dev
	make instance-destroy

# --------------------------------------

PSQL := docker exec --interactive $(_TTY) database psql -d postgres -U postgres -t -c

image-create: stop # Create data and database images
	make \
		download \
		build \
		start \
		_image-create-wait \
		_image-create-snapshot \
		stop

_image-create-wait:
	docker logs --follow data &
	while true; do
		sleep 1
		exists=$$($(PSQL) "select to_regclass('_metadata')" 2> /dev/null | tr -d '[:space:]')
		if [ -n "$$exists" ]; then
			count=$$($(PSQL) "select count(*) from _metadata where label = 'created'" 2> /dev/null | tr -d '[:space:]')
			if [ "$$count" -eq 1 ]; then
				break
			fi
		fi
	done

_image-create-snapshot:
	docker stop database
	docker run --interactive $(_TTY) --rm \
		--volume data:/var/lib/postgresql/data \
		--volume $(TMP_DIR):/project \
		alpine:$(DOCKER_ALPINE_VERSION) \
			sh -exc "cd /var/lib/postgresql/data; tar -czf /project/backup.tar.gz ."
	docker cp $(TMP_DIR)/backup.tar.gz database:/var/lib/postgresql/backup.tar.gz
	docker commit database $(DOCKER_REGISTRY)/database:$$(cat build/docker/data/.version)
	docker tag $(DOCKER_REGISTRY)/database:$$(cat build/docker/data/.version) $(DOCKER_REGISTRY)/database:latest

image-test: # Test database image
	docker run --interactive $(_TTY) --detach --rm \
		--name database \
		$(DOCKER_REGISTRY)/database:$$(cat build/docker/data/.version) \
		postgres
	docker logs --follow database &
	while true; do
		sleep 1
		exists=$$($(PSQL) "select to_regclass('_metadata')" 2> /dev/null | tr -d '[:space:]')
		if [ -n "$$exists" ]; then
			count=$$($(PSQL) "select count(*) from _metadata where label = 'created'" 2> /dev/null | tr -d '[:space:]')
			if [ "$$count" -eq 1 ]; then
				break
			fi
		fi
	done
	docker rm --force database

image-create-repository: # Create registry for the data and database images
	make docker-create-repository \
		NAME=data \
		POLICY_FILE=build/automation/lib/aws/aws-ecr-create-repository-policy-custom.json \
		2> /dev/null ||:
	make docker-create-repository \
		NAME=database \
		POLICY_FILE=build/automation/lib/aws/aws-ecr-create-repository-policy-custom.json \
		2> /dev/null ||:

image-push: # Push the data and database images to the registry
	make docker-push NAME=data VERSION=$$(cat build/docker/data/.version)
	make docker-push NAME=database VERSION=$$(cat build/docker/data/.version)

instance-plan: # Show the creation instance plan - optional: NAME=[instance name, defaults to "test"]
	make terraform-plan \
		PROFILE=dev \
		NAME=$(or $(NAME), test)

instance-create: project-config # Create an instance - optional: NAME=[instance name, defaults to "test"]
	make terraform-apply-auto-approve \
		PROFILE=dev \
		NAME=$(or $(NAME), test)
	make aws-rds-describe-instance \
		PROFILE=dev \
		NAME=$(or $(NAME), test)

instance-destroy: # Destroy the instance - optional: NAME=[instance name, defaults to "test"]
	make terraform-destroy-auto-approve \
		PROFILE=dev \
		NAME=$(or $(NAME), test)

instance-populate: # Populate the instance with the data - optional: NAME=[instance name, defaults to "test"],VERSION=[version or tag of the data image, defaults to the just built image]
	eval "$$(make secret-fetch-and-export-variables NAME=uec-dos-api-tdb-test-dev/deployment)"
	make k8s-deploy-job \
		STACK=data \
		SECONDS=600 \
		PROFILE=dev \
		NAME=$(or $(NAME), test) \
		VERSION=$(or $(VERSION), $$(cat build/docker/data/.version))

# ==============================================================================
# Pipeline targets

build-artefact:
	echo TODO: $(@)

publish-artefact:
	echo TODO: $(@)

backup-data:
	echo TODO: $(@)

provision-infractructure:
	echo TODO: $(@)

deploy-artefact:
	echo TODO: $(@)

apply-data-changes:
	echo TODO: $(@)

# --------------------------------------

run-static-analisys:
	echo TODO: $(@)

run-unit-test:
	echo TODO: $(@)

run-smoke-test:
	echo TODO: $(@)

run-integration-test:
	echo TODO: $(@)

run-contract-test:
	echo TODO: $(@)

run-functional-test:
	[ $$(make project-branch-func-test) != true ] && exit 0
	echo TODO: $(@)

run-performance-test:
	[ $$(make project-branch-perf-test) != true ] && exit 0
	echo TODO: $(@)

run-security-test:
	[ $$(make project-branch-sec-test) != true ] && exit 0
	echo TODO: $(@)

# --------------------------------------

remove-unused-environments:
	echo TODO: $(@)

remove-old-artefacts:
	echo TODO: $(@)

remove-old-backups:
	echo TODO: $(@)

# --------------------------------------

pipeline-finalise: ## Finalise pipeline execution - mandatory: PIPELINE_NAME,BUILD_STATUS
	# Check if BUILD_STATUS is SUCCESS or FAILURE
	make pipeline-send-notification

pipeline-send-notification: ## Send Slack notification with the pipeline status - mandatory: PIPELINE_NAME,BUILD_STATUS
	eval "$$(make aws-assume-role-export-variables)"
	eval "$$(make secret-fetch-and-export-variables NAME=$(PROJECT_GROUP_SHORT)-$(PROJECT_NAME_SHORT)-$(PROFILE)/deployment)"
	make slack-it

# --------------------------------------

pipeline-check-resources: ## Check all the pipeline deployment supporting resources - optional: PROFILE=[name]
	profiles="$$(make project-list-profiles)"
	# table: $(PROJECT_GROUP_SHORT)-$(PROJECT_NAME_SHORT)-deployment
	# secret: $(PROJECT_GROUP_SHORT)-$(PROJECT_NAME_SHORT)-$(PROFILE)/deployment
	# bucket: $(PROJECT_GROUP_SHORT)-$(PROJECT_NAME_SHORT)-$(PROFILE)-deployment
	# certificate: SSL_DOMAINS_PROD
	# repos: DOCKER_REPOSITORIES

pipeline-create-resources: ## Create all the pipeline deployment supporting resources - optional: PROFILE=[name]
	profiles="$$(make project-list-profiles)"
	#make aws-dynamodb-create NAME=$(PROJECT_GROUP_SHORT)-$(PROJECT_NAME_SHORT)-deployment ATTRIBUTE_DEFINITIONS= KEY_SCHEMA=
	#make secret-create NAME=$(PROJECT_GROUP_SHORT)-$(PROJECT_NAME_SHORT)-$(PROFILE)/deployment VARS=DB_PASSWORD,SMTP_PASSWORD,SLACK_WEBHOOK_URL
	#make aws-s3-create NAME=$(PROJECT_GROUP_SHORT)-$(PROJECT_NAME_SHORT)-$(PROFILE)-deployment
	#make ssl-request-certificate-prod SSL_DOMAINS_PROD
	#make docker-create-repository NAME=NAME_TEMPLATE_TO_REPLACE
	make secret-create \
		NAME=$(PROJECT_GROUP_SHORT)-$(PROJECT_NAME_SHORT)-dev/deployment \
		VARS=SLACK_WEBHOOK_URL

# ==============================================================================

.PHONY: \
	image-create \
	stop
