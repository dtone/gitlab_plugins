#
# @author frantisek.svoboda@dtone.com
#
CONTAINER_NAME?=gitlab_plugins
HOSTNAME?=localhost
DOCKER_ENVS=
EVENT?={"event_name": "event to skip"}
NAME?=gitlab_plugins
PORT?=2019
VERSION?= latest
.PHONY: build clean-build default emit-event help install run run-docker

build:
	docker image build -t $(NAME):$(VERSION) .
clean-build:
	docker image build -t $(NAME):$(VERSION) --no-cache .
default: clean-build
emit-event:
	echo '$(EVENT)' | nc $(HOSTNAME) $(PORT)
help:
	@echo -e "\nAvailable targets are:\n"
	@echo -e "\tbuild - Build docker image"
	@echo -e "\tclean-build - Build docker image with no cache"
	@echo -e "\tdefault - clean-build"
	@echo -e "\temit-event - emits EVENT in one-line JSON to running GigLab plugins on HOSTNAME and PORT"
	@echo -e "\tinstall - install bundler and all gems"
	@echo -e "\trun - run GitLab plugins on HOSTNAME and PORT"
	@echo -e "\trun-docker - run GitLab plugins in detached docker container with name and hostname set to CONTAINER_NAME"
	@echo -e ""
install:
	gem install bundler
	bundle install --jobs `nproc`
run:
	bundle exec ruby plugins.rb -p $(PORT)
run-docker:
	docker run --hostname=$(CONTAINER_NAME) --name=$(CONTAINER_NAME) --rm -p $(PORT):$(PORT) $(DOCKER_ENVS) $(NAME):$(VERSION)
