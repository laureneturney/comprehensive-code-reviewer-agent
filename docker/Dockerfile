# All-in-one image built ONLY from the vendored assets in this repository.
# The base image must already be available to the Docker daemon (pre-pulled or mirrored);
# nothing else is fetched. `python:3.12` (not -slim) ships git, which every tool needs.
#
#   docker build -f docker/Dockerfile -t ccra:local .
#   docker run --rm -v "$PWD:/work" -w /work --env-file .ccra/env ccra:local review --reporter local
ARG BASE_IMAGE=python:3.12
FROM ${BASE_IMAGE}

ENV CCRA_HOME=/opt/ccra/.ccra \
    OCR_NO_UPDATE=1 \
    LITELLM_LOCAL_MODEL_COST_MAP=True \
    HF_HUB_OFFLINE=1 \
    PATH=/opt/ccra/.ccra/bin:/opt/ccra/bin:$PATH

WORKDIR /opt/ccra
COPY bin bin
COPY scripts scripts
COPY config config
COPY vendor vendor
COPY tools tools
COPY VERSION README.md ./

RUN scripts/install.sh && ccra doctor

WORKDIR /work
ENTRYPOINT ["ccra"]
CMD ["--help"]
