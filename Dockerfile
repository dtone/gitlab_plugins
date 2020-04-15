# use latest Ruby image and latest stable Debian
FROM ruby:slim-buster
LABEL maintainer="Frantisek Svoboda <fresco@dtone.com>"

RUN apt-get update \
 && apt-get install -y make gcc g++

WORKDIR gitlab_plugins
COPY . .
RUN make install

USER nobody
EXPOSE 2019/tcp
ENTRYPOINT ["make"]
CMD ["run"]