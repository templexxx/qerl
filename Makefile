REBAR := ./rebar3

all:get-deps compile

get-deps:
		@$(REBAR) upgrade

compile:
		@$(REBAR) compile

clean:
		@$(REBAR) clean

run:
		erl -pa _build/default/lib/*/ebin
