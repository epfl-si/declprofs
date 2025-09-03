FROM docker.io/library/debian:bookworm AS perl-base

RUN set -e -x; export DEBIAN_FRONTEND=noninteractive; \
  apt -qy update; apt -qy install msmtp msmtp-mta libdbd-mysql-perl libwww-perl cpanminus \
    apache2 libapache2-mod-auth-openidc ; \
  apt clean

COPY docker/msmtprc /etc/msmtprc

FROM perl-base AS perl-build

RUN set -e -x; export DEBIAN_FRONTEND=noninteractive; \
  apt -qy update; apt -qy install build-essential libmariadb-dev

COPY cpanfile cpanfile
RUN cpanm --installdeps --notest . || { cat /root/.cpanm/work/*/build.log; exit 1; }

FROM perl-base
COPY --from=perl-build /usr/local/share/perl /usr/local/share/perl
COPY --from=perl-build /usr/local/lib/x86_64-linux-gnu/perl /usr/local/lib/x86_64-linux-gnu/perl

RUN mkdir -p /app/etc /app/sessions
RUN chmod 1777 /app/sessions

COPY docker/httpd.conf /etc/apache2/apache2.conf
COPY perllib /usr/local/lib/site_perl/

COPY declprofs.js declprofs.css /app/htdocs/extra/
COPY images /app/htdocs/images
COPY cgi-bin /app/cgi-bin/
COPY tmpl /app/tmpl
# The `declprofs` script will stat() itself to determine the build timestamp:
RUN touch /app/cgi-bin/declprofs

ENTRYPOINT /usr/sbin/apache2 -DFOREGROUND
