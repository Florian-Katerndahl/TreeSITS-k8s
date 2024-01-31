FROM ghcr.io/osgeo/gdal:ubuntu-small-latest

LABEL maintainer="Florian Katerndahl <florian@katerndahl.com>"
LABEL version="latest"
LABEL description="Dependency collection for tree species classification from satellite time series using neural networks"
LABEL homepage="https://github.com/JKfuberlin/SITS-NN-Classification"

ENV DEBIANFRONTEND=noninteractive

WORKDIR /usr/src

RUN apt update && \
    apt upgrade -y && \
    apt install -y bc python3-pip jq git wget nfs-common

# courtesy of https://github.com/davidfrantz/base_image/blob/fab4748fe6d017788b7e5aa109266791838afb37/Dockerfile
RUN groupadd docker && \
	useradd -m docker -g docker -p docker && \
	chmod 0777 /home/docker && \
	chgrp docker /usr/local/bin && \
	mkdir -p /usr/scripts && \
	chown -R docker:docker /usr/src 

ENV HOME /home/docker
ENV PATH="${PATH}:/home/docker/.local/bin/"
USER docker

RUN wget -O install.py https://install.python-poetry.org && \
    python3 install.py

RUN git clone https://github.com/Florian-Katerndahl/SITS-NN-Classification.git sits && \
    cd sits && \
    mv .poetry/cpu-inference.toml pyproject.toml && \
    poetry lock && \
    poetry build

RUN mkdir ${HOME}/python-scripts && \
    cp /usr/src/sits/apps/*.py ${HOME}/python-scripts && \
    chmod +x ${HOME}/python-scripts/*.py

ENV PATH="${PATH}:/home/docker/python-scripts"
ENV PYTHONPATH="{PYTHONPATH}:/home/docker/python-scripts"

WORKDIR ${HOME}

RUN pip install /usr/src/sits/dist/sits_classification-0.1.0-py3-none-any.whl

RUN rm -rf /usr/src/sits && \
    python3 /usr/src/install.py --uninstall && \
    rm /usr/src/install.py && \
    rm -rf .cache/*

USER root

RUN apt purge -y python3-pip && \
    apt autoremove -y && \
    apt clean

USER docker

CMD [ "bash" ]
