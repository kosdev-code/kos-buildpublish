# Use the Azul Zulu base image for Java 17
FROM azul/zulu-openjdk:17 as java

# Create a new stage for Node.js
FROM node:lts as node

# Set environment variables for Java
ENV JAVA_HOME=/usr/lib/jvm/zulu17
ENV PATH=$JAVA_HOME/bin:$PATH

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
    apt-get install -y p7zip-full jq && \
    rm -rf /var/lib/apt/lists/*

# Copy Java from the first stage to the new stage
COPY --from=java $JAVA_HOME $JAVA_HOME

WORKDIR /root

COPY load_secrets.sh /usr/local/bin 
COPY kos_build_handler.sh /usr/local/bin
COPY lib/kabtool.jar /usr/local/lib
COPY lib/publishtool.jar /usr/local/lib
COPY publishtool /usr/local/bin
COPY kabtool     /usr/local/bin

# Verify installations
RUN java -version && \
    node -v && \
    npm -v && \
    mvn -v; \
    chmod 755 /usr/local/bin/load_secrets.sh /usr/local/bin/kabtool \
              /usr/local/bin/publishtool /usr/local/bin/kos_build_handler.sh

ENTRYPOINT ["kos_build_handler.sh"]



