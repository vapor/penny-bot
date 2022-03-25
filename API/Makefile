DEPLOY_PACKAGES := PennyAPI

DOCKER_IMAGE := swift-lambda-builder
DOCKER_IMAGE_INFO := .build/${DOCKER_IMAGE}.json
#SWIFT_RELEASE_OPTS := -c release
SWIFT_RELEASE_OPTS := -c release -Xswiftc -static-stdlib
#SAM_CONFIG := samconfig.toml

.PHONY: all
all: bootstrap deploy

.PHONY: clean
clean:
	swift package clean

.PHONY: bootstrap
bootstrap: ${DOCKER_IMAGE_INFO}

.PHONY: package_all
package_all: $(DEPLOY_PACKAGES:%=.build/lambda/%.zip)
	@echo $<

# .PHONY: deploy
# deploy: #package_all
# 	sam build
# 	[ -f ${SAM_CONFIG} ] && (sam deploy || echo "Failed") || sam deploy --guided

# ${DOCKER_IMAGE_INFO}:
# 	docker inspect ${DOCKER_IMAGE} > /dev/null 2>&1 || docker build -t ${DOCKER_IMAGE} .
# 	mkdir -p `dirname ${DOCKER_IMAGE_INFO}`
# 	docker inspect ${DOCKER_IMAGE} > ${DOCKER_IMAGE_INFO}

.build/lambda/%.zip: .build/release/%
	@echo == package $(notdir $<)
	docker run \
	  --rm \
	  --volume "$(shell pwd)/:/src" \
	  --workdir "/src/" \
	  ${DOCKER_IMAGE} \
	  scripts/package.sh $(notdir $<)

# TODO: check dependencies
.build/release/%:
	@echo == build $(notdir $@)
	docker run \
	  --rm \
	  --volume "$(shell pwd)/:/src" \
	  --workdir "/src/" \
	  ${DOCKER_IMAGE} \
	  swift build --product $(notdir $@) ${SWIFT_RELEASE_OPTS}

# for sam build, example: sam build HelloWorldAPIFunction
# TODO: dependency does not work, package_all first
#build-%: .build/lambda/$(patsubst build-%Function,%.zip,$@)
# build-%: package_all
# 	test -d "${ARTIFACTS_DIR}" || exit 1
# 	unzip .build/lambda/$(patsubst build-%Function,%.zip,$@) -d ${ARTIFACTS_DIR}/