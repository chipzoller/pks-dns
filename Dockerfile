FROM mcr.microsoft.com/powershell:6.2.2-ubuntu-xenial
LABEL maintainer="Chip Zoller <chipzoller@gmail.com>"
LABEL description="This image extracts the hostname and master IP \
from a Kubernetes cluster provisioned from VMware PKS \
and automates the DNS record creation on a remote machine."
ADD https://raw.githubusercontent.com/chipzoller/pks-dns/master/pks-dns.ps1 /
RUN apt-get update && apt-get install -y curl \
    openssh-client \
    sshpass && rm -rf /var/lib/apt/lists/*
RUN curl -sLO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl && chmod +x /kubectl
CMD ["pwsh"]
