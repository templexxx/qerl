-module(qerl).

%% API exports
-export([start/0]).

-define(APP, qerl).

-include("config.hrl").

%%====================================================================
%% API functions
%%====================================================================


start() ->
	application:load(?APP),
	{ok, Apps} = application:get_key(?APP, applications),
	[application:start(App) || App <- Apps],
	inets:start(),
	application:start(?APP).

%%====================================================================
%% Internal functions
%%====================================================================
