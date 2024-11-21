# at the time of writing, CUDA 12.6 is installed on EOLab VMs
# Wieso ist das jetzt 11.4 in der VM???? Does this depend on the VM flavor? .1 had 12.6; .4 has 11.4?
FROM pytorch/pytorch:2.4.1-cuda12.4-cudnn9-runtime

LABEL maintainer="Florian Katerndahl <florian@katerndahl.com>"
LABEL version="latest"
LABEL description="Dependency Collection for Tree Species Classification From Satellite Time Series Using Neural Networks"
LABEL homepage="https://github.com/Florian-Katerndahl/TreeSITS-k8s"

ENV HOME="/home/docker"
ENV DEBIANFRONTEND=noninteractive
ENV TZ=Europe/Berlin
ENV PATH="${PATH}:$HOME/.local/bin"

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone

RUN apt-get update && \
    apt-get install -y jq git wget nfs-common pipx && \
    pipx install poetry

RUN git clone https://github.com/Florian-Katerndahl/sits-dl.git && \
    cd sits-dl && \
    sed -i -e "s/cu118/cu124/" -e "s/pytorch11/pytorch12/" pyproject.toml && \
    poetry build -f wheel && \
    pipx install dist/sits_dl*.whl && \
    cd .. && \
    rm -fr sits-dl

CMD [ "bash" ]
