REBAR := ./rebar3

all:get-deps compile

get-deps:
		@$(REBAR) deps

compile:
		@$(REBAR) compile

clean:
		@$(REBAR) clean

run:
		erl -pa deps/*/ebin -pa ./ebin
