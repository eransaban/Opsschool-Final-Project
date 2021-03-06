FROM openjdk:8-slim

# Those are allowed to be changed at build time
ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000
ARG git_lfs_version=2.9.1

ENV JENKINS_HOME=/var/jenkins_home \
    JENKINS_USER=${user}

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl dumb-init git libltdl7 openssh-client procps docker.io unzip\
    && rm -rf /var/lib/apt/lists/* \
    \
    # Install git LFS
    && curl -#LSo git-lfs.deb https://packagecloud.io/github/git-lfs/packages/debian/stretch/git-lfs_${git_lfs_version}_amd64.deb/download.deb \
    && dpkg -i git-lfs.deb \
    && rm -f git-lfs.deb \
    \
    # Jenkins is run with user `jenkins`, uid = 1000
    # If you bind mount a volume from the host or a data container,
    # ensure you use the same uid
    && groupadd -g ${gid} ${group} \
    && useradd -d "$JENKINS_HOME" -u ${uid} -g ${gid} -m -s /bin/bash ${user} \
    \
    # Tweak global SSH client configuration
    && sed -i '/^Host \*/a \ \ \ \ ServerAliveInterval 30' /etc/ssh/ssh_config \
    && sed -i '/^Host \*/a \ \ \ \ StrictHostKeyChecking no' /etc/ssh/ssh_config \
    && sed -i '/^Host \*/a \ \ \ \ UserKnownHostsFile /dev/null' /etc/ssh/ssh_config

RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
RUN chmod 755 ./kubectl
RUN mv ./kubectl /usr/local/bin

RUN curl -o aws-iam-authenticator https://amazon-eks.s3-us-west-2.amazonaws.com/1.14.6/2019-08-22/bin/linux/amd64/aws-iam-authenticator
RUN chmod +x ./aws-iam-authenticator
RUN mv ./aws-iam-authenticator /usr/local/bin

RUN curl "https://d1vvhvl2y92vvt.cloudfront.net/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
RUN unzip awscliv2.zip
RUN ./aws/install 
# Jenkins home directory is a volume, so configuration and build history
# can be persisted and survive image upgrades
VOLUME $JENKINS_HOME

COPY jenkins-slave /usr/local/bin/jenkins-slave

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/usr/local/bin/jenkins-slave"]
