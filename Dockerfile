FROM httpd:bookworm AS perl-base

RUN set -e -x; export DEBIAN_FRONTEND=noninteractive; \
  apt -qy update; apt -qy install libdbd-mysql-perl libwww-perl cpanminus; \
  apt clean

FROM perl-base AS perl-build

RUN set -e -x; export DEBIAN_FRONTEND=noninteractive; \
  apt -qy update; apt -qy install build-essential libmariadb-dev

COPY cpanfile cpanfile
RUN cpanm --installdeps --notest . || { cat /root/.cpanm/work/*/build.log; exit 1; }

FROM perl-base
COPY --from=perl-build /usr/local/share/perl /usr/local/share/perl
COPY --from=perl-build /usr/local/lib/x86_64-linux-gnu/perl /usr/local/lib/x86_64-linux-gnu/perl
