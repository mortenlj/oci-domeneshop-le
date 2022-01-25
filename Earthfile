VERSION 0.6

FROM python:3

# builtins must be declared
ARG EARTHLY_GIT_PROJECT_NAME
ARG EARTHLY_GIT_SHORT_HASH

# Override from command-line on CI
ARG main_image=ghcr.io/$EARTHLY_GIT_PROJECT_NAME
ARG VERSION=$EARTHLY_GIT_SHORT_HASH

WORKDIR /

oci-sdk:
    RUN wget https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh
    RUN mkdir -p /opt/oci-sdk && \
        chmod a+x install.sh && \
        ./install.sh --accept-all-defaults --install-dir /opt/oci-sdk
    SAVE ARTIFACT /opt/oci-sdk/*
    SAVE IMAGE --cache-hint

certbot:
    RUN python3 -m venv /opt/certbot/ && \
        /opt/certbot/bin/pip install --upgrade pip && \
        /opt/certbot/bin/pip install certbot && \
        /opt/certbot/bin/pip install certbot-dns-domeneshop
    SAVE ARTIFACT /opt/certbot/*
    SAVE IMAGE --cache-hint

docker:
    FROM python:3
    COPY --dir +oci-sdk/ /opt/oci-sdk/
    COPY --dir +certbot/ /opt/certbot/
    COPY renew-certificates.sh /usr/local/bin/

    CMD ["/usr/local/bin/renew-certificates.sh"]

    SAVE IMAGE --push ${main_image}:${VERSION}
    SAVE IMAGE --push ${main_image}:latest

manifests:
    FROM dinutac/jinja2docker:latest
    WORKDIR /manifests
    COPY deploy/* /templates
    RUN --entrypoint -- /templates/cronjob.yaml.j2 > ./deploy.yaml
    RUN --push cat /templates/*.yaml >> ./deploy.yaml
    SAVE ARTIFACT ./deploy.yaml AS LOCAL deploy.yaml

deploy:
    BUILD +docker
    BUILD +manifests
