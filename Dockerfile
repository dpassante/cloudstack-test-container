FROM ubuntu:bionic

MAINTAINER "René Moser" <mail@renemoser.net>

ARG src_url=https://dist.apache.org/repos/dist/dev/cloudstack/4.14.1.0/apache-cloudstack-4.14.1.0-src.tar.bz2

RUN echo 'mysql-server mysql-server/root_password password root' | debconf-set-selections; \
    echo 'mysql-server mysql-server/root_password_again password root' | debconf-set-selections;

RUN apt-get -y update && apt-get dist-upgrade -y && apt-get install -y \
    genisoimage \
    libffi-dev \
    libssl-dev \
    sudo \
    ipmitool \
    maven \
    netcat \
    openjdk-11-jdk \
    python-dev \
    python-mysql.connector \
    python-pip \
    python-setuptools \
    python-paramiko \
    supervisor \
    wget \
    nginx \
    jq \
    mysql-server \
    openssh-client \
    && apt-get clean all \
    && rm -rf /var/lib/apt/lists/*;

# TODO: check if and why this is needed
RUN mkdir -p /root/.ssh \
    && chmod 0700 /root/.ssh \
    && ssh-keygen -t rsa -N "" -f id_rsa.cloud

RUN apt-get install -qqy mysql-server && \
    apt-get clean all && \
    mkdir -p /var/run/mysqld; \
    chown mysql /var/run/mysqld; \
    echo '''sql_mode = "STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION"''' >> /etc/mysql/mysql.conf.d/mysqld.cnf

RUN (/usr/bin/mysqld_safe &); sleep 5; mysqladmin -u root -proot password ''

RUN wget $src_url -O /opt/cloudstack.tar.gz; \
    mkdir -p /opt/cloudstack; \
    tar xvjf /opt/cloudstack.tar.gz -C /opt/cloudstack --strip-components=1

WORKDIR /opt/cloudstack

RUN mvn -Pdeveloper -Dsimulator -DskipTests clean install

RUN (/usr/bin/mysqld_safe &); \
    sleep 5; \
    mvn -Pdeveloper -pl developer -Ddeploydb; \
    mvn -Pdeveloper -pl developer -Ddeploydb-simulator; \
    MARVIN_FILE=$(find /opt/cloudstack/tools/marvin/dist/ -name "Marvin*.tar.gz"); \
    pip install $MARVIN_FILE;

COPY zones.cfg /opt/zones.cfg
COPY nginx_default.conf /etc/nginx/sites-available/default
RUN pip install cs==2.5
COPY run.sh /opt/run.sh
COPY deploy.sh /opt/deploy.sh
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN /opt/deploy.sh

EXPOSE 8888 8080 8096

CMD ["/usr/bin/supervisord"]
