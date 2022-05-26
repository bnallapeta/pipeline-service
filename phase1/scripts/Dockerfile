FROM registry.access.redhat.com/ubi8/ubi-minimal:8.6
WORKDIR /
RUN mkdir /workspace && chmod 777 /workspace && chown 65532:65532 /workspace
COPY ./register.sh /usr/local/bin/register.sh
RUN KUBE_VERSION=v1.24.0 && \
    curl -L -o /usr/local/bin/kubectl "https://dl.k8s.io/release/$KUBE_VERSION/bin/linux/amd64/kubectl" && \
    chmod +x /usr/local/bin/kubectl
USER 65532:65532
VOLUME /workspace
WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/register.sh"]
