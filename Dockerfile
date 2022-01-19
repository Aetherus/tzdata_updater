FROM hexpm/elixir:1.13.1-erlang-24.2-alpine-3.15.0

ARG git_repo

ENV MIX_ENV=prod LANG=C.UTF-8 TZ=Asia/Shanghai HOME=/app

RUN apk add --no-cache git inotify-tools

WORKDIR $HOME

RUN mkdir .ssh

COPY mix.exs mix.lock ./

RUN mix local.hex --force
RUN mix local.rebar --force
RUN mix do deps.get, deps.compile

COPY . .

RUN mix compile

VOLUME /app/tmp 

CMD mix run --no-halt
