VERSION 0.6

oci-sdk:
    FROM python:3
    WORKDIR /tmp
    RUN wget https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh
    RUN mkdir -p /opt/oci-sdk && \
        chmod a+x install.sh && \
        ./install.sh --accept-all-defaults --install-dir /opt/oci-sdk
    SAVE ARTIFACT /opt/oci-sdk/*
    SAVE IMAGE --cache-hint

certbot:
    FROM python:3
    WORKDIR /tmp
    RUN python3 -m venv /opt/certbot/ && \
        /opt/certbot/bin/pip install --upgrade pip && \
        /opt/certbot/bin/pip install certbot && \
        /opt/certbot/bin/pip install certbot-dns-domeneshop
    SAVE ARTIFACT /opt/certbot/*
    SAVE IMAGE --cache-hint

docker:
    FROM python:3
    RUN apt-get --quiet --yes update && apt-get --quiet --yes install jq
    COPY --dir +oci-sdk/ /opt/oci-sdk/
    COPY --dir +certbot/ /opt/certbot/

    WORKDIR /app
    COPY renew-certificates.sh .
    COPY update_certificate_in_LB.sh .
    COPY certbot.ini .

    CMD ["/app/renew-certificates.sh"]

    # builtins must be declared
    ARG EARTHLY_GIT_PROJECT_NAME
    ARG EARTHLY_GIT_SHORT_HASH

    # Override from command-line on CI
    ARG main_image=ghcr.io/$EARTHLY_GIT_PROJECT_NAME
    ARG VERSION=$EARTHLY_GIT_SHORT_HASH

    SAVE IMAGE --push ${main_image}:${VERSION}
    SAVE IMAGE --push ${main_image}:latest

test:
    FROM earthly/dind:alpine
    WORKDIR /test
    COPY secret_contents/ /test/secret_contents
    WITH DOCKER --load test-image:latest=+docker
        RUN docker run \
            --env OCI_CLI_CONFIG_FILE=/var/run/secrets/ibidem.no/oci-sa/config \
            --env OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING=True \
            --mount type=bind,src=/test/secret_contents/oci-sa,dst=/var/run/secrets/ibidem.no/oci-sa,readonly \
            --mount type=bind,src=/test/secret_contents/domeneshop,dst=/var/run/secrets/ibidem.no/domeneshop,readonly \
            --mount type=tmpfs,dst=/tmp \
            test-image:latest
    END

manifests:
    FROM dinutac/jinja2docker:latest
    WORKDIR /manifests
    COPY deploy/* /templates
    ARG main_image=ghcr.io/$EARTHLY_GIT_PROJECT_NAME
    ARG VERSION=$EARTHLY_GIT_SHORT_HASH
    RUN --entrypoint -- /templates/cronjob.yaml.j2 > ./deploy.yaml
    RUN cat /templates/*.yaml >> ./deploy.yaml
    SAVE ARTIFACT ./deploy.yaml AS LOCAL deploy.yaml

deploy:
    BUILD --platform=linux/amd64 --platform=linux/arm64 +docker
    BUILD +manifests
