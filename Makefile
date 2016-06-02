MESOS_VER=0.27.1
MESOS_HELPER_URL=https://codeload.github.com/danigiri/mesos-build-helper/zip/$(MESOS_VER)


all: createvmservices build-zookeeper build-docker-registry compose-services createvmhosts network \
	build-mesos-master build-mesos-marathon compose-host-master build-mesos-slave compose-host-slave

build: build-common build-zookeeper build-mesos-common build-mesos-master build-mesos-slave \
	build-mesos-marathon build-docker-registry

build-without-slave: build-common build-zookeeper build-mesos-common build-mesos-master \
	build-mesos-marathon build-docker-registry

build-common-services:
	eval $$(docker-machine env services) ; cd common ; docker build -t mesoscope/common .

build-common-slave:
	eval $$(docker-machine env host1) ; cd common ; docker build -t mesoscope/common .

build-common-master:
	eval $$(docker-machine env host0) ; cd common ; docker build -t mesoscope/common .

build-zookeeper: build-common-services
	eval $$(docker-machine env services) ; cd zookeeper && docker build -t mesoscope/zookeeper .

mesos-common/mesos-$(MESOS_VER)-1.x86_64.rpm:
	mkdir -p tmp && cd tmp && curl -s -S "$(MESOS_HELPER_URL)" -o mesos-build-helper-$(MESOS_VER).zip
	unzip -q -u tmp/mesos-build-helper-$(MESOS_VER).zip -d tmp
	DOCKER_FILE=Dockerfile-ubuntu cd tmp/mesos-build-helper-$(MESOS_VER) && ./script/build
	cp -v tmp/mesos-build-helper-$(MESOS_VER)/mesos-$(MESOS_VER)-1.x86_64.rpm mesos-common

build-mesos-common-slave: build-common-slave mesos-common/mesos-$(MESOS_VER)-1.x86_64.rpm
	eval $$(docker-machine env host1) ; cd mesos-common ; docker build -t mesoscope/mesos-common .

build-mesos-common-master: build-common-master mesos-common/mesos-$(MESOS_VER)-1.x86_64.rpm
	eval $$(docker-machine env host0) ; cd mesos-common ; docker build -t mesoscope/mesos-common .

build-mesos-master: build-mesos-common-master
	eval $$(docker-machine env host0) ; cd mesos-master && docker build -t mesoscope/mesos-master .

build-mesos-slave: build-mesos-common-slave
	eval $$(docker-machine env host1) ; cd mesos-slave ; docker build -t mesoscope/mesos-slave .

build-mesos-marathon: build-mesos-common
	eval $$(docker-machine env host0) ; cd mesos-marathon && docker build -t mesoscope/mesos-marathon .

build-docker-registry: build-common-services
	eval $$(docker-machine env services) ; cd docker-registry && docker build -t mesoscope/docker-registry .

network:
	eval $$(docker-machine env host0); docker network create --driver overlay "mesos_network"

createvmservices:
	docker-machine create --driver virtualbox --virtualbox-no-share services && eval $$(docker-machine env services)
	sleep 1

createvmhosts:
	docker-machine create --driver virtualbox --virtualbox-no-share --engine-opt="cluster-advertise=eth1:2376" --engine-opt="cluster-store=zk://$$(docker-machine ip services):2181" host0
	docker-machine create --driver virtualbox --virtualbox-no-share --engine-opt="cluster-advertise=eth1:2376" --engine-opt="cluster-store=zk://$$(docker-machine ip services):2181" host1
	sleep 1

compose-services:
	eval $$(docker-machine env services) ; cd composes/services ; docker-compose up -d

compose-host-slave:
	eval $$(docker-machine env host1) ; cd composes/host_slave ; docker-compose up -d

compose-host-master:
	eval $$(docker-machine env host0) ; cd composes/host_master ; docker-compose up -d

decompose:
	eval $$(docker-machine env services) ; cd composes/services ;  docker-compose kill && docker-compose rm -f
	eval $$(docker-machine env host1) ; cd composes/host_slave ; docker-compose kill && docker-compose rm -f
	eval $$(docker-machine env host0) ; cd composes/host_master ; docker-compose kill && docker-compose rm -f	

destroy:
	eval $$(docker-machine env services) ; cd composes/services ;  docker-compose kill && docker-compose rm -f
	eval $$(docker-machine env host1) ; cd composes/host_slave ; docker-compose kill && docker-compose rm -f
	eval $$(docker-machine env host0) ; cd composes/host_master ; docker-compose kill && docker-compose rm -f
	docker-machine rm -y -f services host0 host1

test:
	cd test && sh test-mesoscope.sh

.PHONY: all build build-common build-zookeeper build-mesos-common build-mesos-master build-mesos-slave \
	build-mesos-marathon build-docker-registry compose destroy test
