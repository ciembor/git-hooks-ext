FROM alpine:3.24 AS build

RUN apk add --no-cache build-base
WORKDIR /src
COPY Makefile VERSION ./
COPY src ./src
RUN make

FROM alpine:3.24

LABEL org.opencontainers.image.source="https://github.com/ciembor/git-hooks-ext"
LABEL org.opencontainers.image.licenses="GPL-2.0-only"

RUN apk add --no-cache git
COPY --from=build /src/git-hooks-ext /usr/local/bin/git-hooks-ext

ENTRYPOINT ["git-hooks-ext"]
CMD ["--version"]
