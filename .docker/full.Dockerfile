FROM ghcr.io/osgeo/gdal:ubuntu-small-3.8.4

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

RUN cp /usr/src/sits/dist/sits_classification-0.1.0-py3-none-any.whl ${HOME}

RUN rm -rf /usr/src/sits && \
    python3 /usr/src/install.py --uninstall && \
    rm /usr/src/install.py && \
    rm -rf .cache/*

USER root

#RUN apt purge -y python3-pip && \
#    apt autoremove -y && \
#    apt clean

# Steps below are mostly taken from https://github.com/davidfrantz/base_image/blob/main/Dockerfile and https://github.com/davidfrantz/force/blob/main/Dockerfile
# Maybe switiching to ROOT and installing python3.9 would have done the trick as well - who knows

ENV TZ=Europe/Berlin
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt update --fix-missing && \
    apt install -y unzip dos2unix curl build-essential libarmadillo-dev libfltk1.3-dev libgsl0-dev lockfile-progs libxml2-dev \
    rename parallel apt-utils cmake libgtk2.0-dev pkg-config libavcodec-dev libavformat-dev libswscale-dev pandoc libudunits2-dev r-base aria2 \
    r-cran-rmarkdown r-cran-plotly r-cran-stringi r-cran-stringr r-cran-tm r-cran-knitr r-cran-dplyr r-cran-wordcloud r-cran-igraph \
    r-cran-htmlwidgets r-cran-raster r-cran-sp r-cran-rgdal r-cran-units r-cran-sf r-cran-snow r-cran-snowfall && \
    pip3 install git+https://github.com/ernstste/landsatlinks.git && \
    Rscript -e 'install.packages("bib2df",      repos="https://cloud.r-project.org")' && \
    Rscript -e 'install.packages("wordcloud2",  repos="https://cloud.r-project.org")' && \
    Rscript -e 'install.packages("network",     repos="https://cloud.r-project.org")' && \
    Rscript -e 'install.packages("intergraph",  repos="https://cloud.r-project.org")' && \
    Rscript -e 'install.packages("getopt",      repos="https://cloud.r-project.org")' && \
    # Clear installation data
    apt-get clean && rm -r /var/cache/

# Install folder
ENV INSTALL_DIR /opt/install/src

# Build OpenCV from source
RUN mkdir -p $INSTALL_DIR/opencv && cd $INSTALL_DIR/opencv && \
    wget https://github.com/opencv/opencv/archive/4.1.0.zip \
    && unzip 4.1.0.zip && \
    mkdir -p $INSTALL_DIR/opencv/opencv-4.1.0/build && \
    cd $INSTALL_DIR/opencv/opencv-4.1.0/build && \
    cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local .. \
    && make -j7 \
    && make install \
    && make clean && \
    mkdir -p $INSTALL_DIR/splits && \
    cd $INSTALL_DIR/splits && \
    wget http://sebastian-mader.net/wp-content/uploads/2017/11/splits-1.9.tar.gz && \
    tar -xzf splits-1.9.tar.gz && \
    cd $INSTALL_DIR/splits/splits-1.9 && \
    ./configure CPPFLAGS="-I /usr/include/gdal" CXXFLAGS=-fpermissive \
    && make \
    && make install \
    && make clean && \
    rm -rf $INSTALL_DIR

# Environment variables
ENV SOURCE_DIR $HOME/src/force
ENV INSTALL_DIR $HOME/bin

# build args
ARG debug=disable

# Copy src to SOURCE_DIR
RUN mkdir -p $SOURCE_DIR
WORKDIR $SOURCE_DIR

# Build, install, check FORCE
RUN git clone https://github.com/Florian-Katerndahl/force.git && \
    cd force && \
    # currently, my changes are in develop
    #git checkout tags/v3.7.12 && \
    git switch force-cube-update && \
    ./splits.sh enable && \
    ./debug.sh $debug && \
    sed -i "/^BINDIR=/cBINDIR=$INSTALL_DIR/" Makefile && \
    make -j && \
    make install && \
    make clean && \
    cd $HOME && \
    rm -rf $SOURCE_DIR 

ENV PATH="${PATH}:/home/docker/bin"

WORKDIR ${HOME}

USER docker

CMD [ "bash" ]
