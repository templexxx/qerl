REBAR := ./rebar3

all:get-deps compile

deps:
		@$(REBAR) upgrade

compile:
		@$(REBAR) compile

clean:
		@$(REBAR) clean

run:
		erl -pa deps/*/ebin -pa ./ebin
