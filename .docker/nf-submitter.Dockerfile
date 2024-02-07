FROM ubuntu:latest

LABEL maintainer="Florian Katerndahl <florian@katerndahl.com>"
LABEL version="0.0.1"
LABEL description="Dependency collection for Nextflow Workflow execution"
LABEL homepage="https://github.com/Florian-Katerndahl/TreeSITS-k8s"

ENV DEBIANFRONTEND=noninteractive

RUN apt update && \
    apt upgrade -y && \
    apt install -y openjdk-17-jre openjdk-17-jre-headless curl wget graphviz

# courtesy of https://github.com/davidfrantz/base_image/blob/fab4748fe6d017788b7e5aa109266791838afb37/Dockerfile
RUN groupadd docker && \
	useradd -m docker -g docker -p docker && \
	chmod 0777 /home/docker

ENV HOME /home/docker
WORKDIR ${HOME}

RUN curl -s https://get.nextflow.io | bash && \
    chmod +x nextflow

RUN chgrp -R docker /home/docker/nextflow && \
    chown -R docker /home/docker/nextflow && \
    chgrp -R docker /home/docker/.nextflow && \
    chown -R docker /home/docker/.nextflow

ENV PATH="${PATH}:/home/docker"
USER docker

COPY workflows /home/docker/workflows

RUN ["bash"]