FROM python:3

# builtins must be declared
ARG EARTHLY_GIT_PROJECT_NAME
ARG EARTHLY_GIT_SHORT_HASH

# Override from command-line on CI
ARG cache_image=ghcr.io/$EARTHLY_GIT_PROJECT_NAME/cache
ARG main_image=ghcr.io/$EARTHLY_GIT_PROJECT_NAME
ARG VERSION=$EARTHLY_GIT_SHORT_HASH

WORKDIR /

oci-sdk:
    RUN wget https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh
    RUN mkdir -p /opt/oci-sdk && \
        chmod a+x install.sh && \
        ./install.sh --accept-all-defaults --install-dir /opt/oci-sdk
    SAVE ARTIFACT /opt/oci-sdk/*
    SAVE IMAGE --push ${cache_image}:oci-sdk

certbot:
    RUN python3 -m venv /opt/certbot/ && \
        /opt/certbot/bin/pip install --upgrade pip && \
        /opt/certbot/bin/pip install certbot && \
        /opt/certbot/bin/pip install certbot-dns-domeneshop
    SAVE ARTIFACT /opt/certbot/*
    SAVE IMAGE --push ${cache_image}:certbot

docker:
    FROM python:3
    COPY --dir +oci-sdk/ /opt/oci-sdk/
    COPY --dir +certbot/ /opt/certbot/
    COPY renew-certificates.sh /usr/local/bin/

    CMD ["/usr/local/bin/renew-certificates.sh"]

    SAVE IMAGE --push ${main_image}:${VERSION}
    SAVE IMAGE --push ${main_image}:latest
