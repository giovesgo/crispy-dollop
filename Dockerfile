FROM alpine:3.8

ENV LANG en_US.utf8

RUN apk --update add --no-cache \
     bash \
     coreutils \
     curl \
     gcc \
     git \
     libc-dev \
     libgcc \
     libpq \
     libstdc++ \
     make \
     musl \
     perl \
     perl-app-cpanminus \
     perl-dev \
     perl-utils \
     postgresql-client \
     postgresql-dev \
     tar

WORKDIR /

# Install Perl modules using cpanm
RUN cpanm --curl --no-wget --no-lwp --notest --no-man-pages \
          Dancer2 \
  Dancer2::Plugin::Database \
  Dancer2::Plugin::FlashNote \
  Dancer2::Session::YAML \
  DBI \
  DBD::Pg \
  Plack \
  Plack::Middleware::Deflater \
  Starman

# Set user and home directory for our code - Not running as root
RUN  addgroup -S dancer -g 433 \
     && adduser -u 431 -S -G dancer -h /home/dancer -s /sbin/nologin dancer \
     && chown dancer:dancer /home/dancer/

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod a+x /usr/local/bin/docker-entrypoint.sh

USER dancer
WORKDIR /home/dancer
ADD app/ /home/dancer/app/
RUN chown -R dancer:dancer /home/dancer/app

EXPOSE 5000
VOLUME /home/dancer

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
