FROM ubuntu:16.04

# Install Ruby and Rails dependencies
RUN apt-get update && apt-get install -y \
  libcurl4-openssl-dev \
  docker.io \
  ruby \
  ruby-dev \
  build-essential \
  libxml2-dev \
  libxslt1-dev \
  zlib1g-dev  #required for gem install

ADD http://pegasus.isi.edu/montage/Montage_v3.3_patched_4.tar.gz /
RUN tar zxvf Montage_v3.3_patched_4.tar.gz && \
    make -C /Montage_v3.3_patched_4 && \
    echo "export PATH=\$PATH:/Montage_v3.3_patched_4/bin" >> /etc/bash.bashrc

COPY . /hyperflow-amqp-executor
WORKDIR /hyperflow-amqp-executor

ENV PATH $PATH:/Montage_v3.3_patched_4/bin

RUN gem install influxdb &&\
    gem install pry &&\
    gem build hyperflow-amqp-executor.gemspec && \
    gem install hyperflow-amqp-executor

CMD hyperflow-amqp-executor