FROM erlang:26-alpine

WORKDIR /app

COPY rebar.config rebar.lock ./
COPY src/ src/
COPY test/ test/

RUN rebar3 compile

CMD ["rebar3", "do", "eunit,", "cover"]
