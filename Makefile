.PHONY: compile test perf cover dialyzer xref check docker-test docker-perf clean

compile:
	rebar3 compile

test:
	rebar3 eunit --verbose

perf:
	rebar3 eunit --module=rets_perf_tests --verbose

cover:
	rebar3 cover --verbose

dialyzer:
	rebar3 dialyzer

xref:
	rebar3 xref

check: compile xref dialyzer test cover

docker-test:
	docker compose run --rm test

docker-perf:
	docker compose run --rm perf

clean:
	rebar3 clean
	docker compose down --rmi local 2>/dev/null || true
