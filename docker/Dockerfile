# Use the Azul Zulu base image for Java 17
FROM azul/zulu-openjdk:17 as java

# Create a new stage for Node.js
FROM node:lts as node

# Set environment variables for Java
ENV JAVA_HOME=/usr/lib/jvm/zulu17
ENV PATH=$JAVA_HOME/bin:$PATH

# The node Docker import includes a user node.  We don't need this and it gets in our way.  So we delete this user.
RUN userdel -r node

# Install Maven
ARG MAVEN_VERSION=3.9.4
ARG MAVEN_URL=https://downloads.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz
RUN curl -fsSL ${MAVEN_URL} -o /tmp/apache-maven.tar.gz && \
    tar -xzf /tmp/apache-maven.tar.gz -C /opt && \
    ln -s /opt/apache-maven-${MAVEN_VERSION} /opt/maven && \
    ln -s /opt/maven/bin/mvn /usr/bin/mvn && \
    rm /tmp/apache-maven.tar.gz

# Set environment variables for Maven
ENV MAVEN_HOME=/opt/maven
ENV PATH=$MAVEN_HOME/bin:$PATH
# the following 2 environments are for the UI build
ENV JAVA_CMD=java
ENV KOS_INSTALL_PATH="/usr/local"

# Install 7z
RUN apt-get update && \
    apt-get install -y p7zip-full jq curl unzip git-lfs squashfs-tools-ng zip zstd xmlstarlet gettext rsync gawk &&  \
    apt-get install -y golang nsis && \
    rm -rf /var/lib/apt/lists/*

# azcopy is downloaded with the kos_gettools step
COPY "download/azcopy/current/azcopy" /usr/local/bin
RUN chmod +x /usr/local/bin/azcopy; \
    chown 0:0 /usr/local/bin/azcopy

# Copy Java from the first stage to the new stage
COPY --from=java $JAVA_HOME $JAVA_HOME

WORKDIR /root

COPY lib/kabtool.jar /usr/local/lib
COPY lib/publishtool.jar /usr/local/lib
COPY tools/* /usr/local/bin/

COPY kos_build_handler.sh /usr/local/bin

# If USER_NAME, USER_ID, GROUP_NAME, and GROUP_ID have been specified, then 
# create user/group specified.  This is for a use case where we volume mount a path from the host to the 
# container and we want permissions to match. (developer use case)
ARG USER_NAME
ARG USER_ID
ARG GROUP_NAME
ARG GROUP_ID
RUN if [ -n "$GROUP_NAME" ] && [ -n "$GROUP_ID" ] && [ -n "$USER_ID" ] && [ -n "$USER_NAME" ]; then \
        groupadd -g $GROUP_ID "$GROUP_NAME"; \
        useradd -m -u $USER_ID -g "${GROUP_NAME:-root}" "$USER_NAME"; \
    fi


# Verify installations
RUN java -version && \
    node -v && \
    npm -v && \
    mvn -v; \
    chmod 755 /usr/local/bin/load_secrets.sh /usr/local/bin/kabtool \
              /usr/local/bin/publishtool /usr/local/bin/kos_*

ENTRYPOINT ["kos_build_handler.sh"]



