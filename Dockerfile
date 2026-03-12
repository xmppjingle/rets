FROM erlang:26-alpine

WORKDIR /app

# Install rebar3
RUN wget https://s3.amazonaws.com/rebar3/rebar3 && \
    chmod +x rebar3 && \
    mv rebar3 /usr/local/bin/

COPY rebar.config rebar.lock ./
COPY src/ src/
COPY test/ test/

RUN rebar3 compile

CMD ["rebar3", "do", "eunit,", "cover"]
