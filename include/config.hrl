%%%-------------------------------------------------------------------
%%% @author templex
%%% @copyright (C) 2016, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 05. Feb 2016 10:31 AM
%%%-------------------------------------------------------------------
-author("templex").


%%Http
-define(API_HOST, "http://api.qiniu.com").
-define(RS_HOST, "http://rs.qiniu.com").
-define(RSF_HOST, "http://rsf.qbox.me").
-define(IO_HOST, "http://iovip.qbox.me").
-define(UP_HOST, "http://up.qiniu.com").
-define(DEF_RETRY_TIME, 3).
-define(DEF_CONTENT_TYPE, <<"application/x-www-form-urlencoded">>).
-define(DEF_OPTIONS, [{connect_timeout, 3000}, {max_connections, 10000}]).
-define(DEF_POOLNAME, 'qiniupool').


%% account
%% NO.1 ak%sk
%% access_key
-define(AK1, "VPVwmTioeHZ8RgurXznTrajwYeb031cKpVr2wlKX").
%% secret key
-define(SK1, "QUQnEVeKqlKER9_I3pJQv6XiOm0R4St9ye8S5dOH").
%% NO.2 ak%sk
%% access_key
-define(AK2, "MY_ACCESS_KEY").
%% secret key
-define(SK2, "MY_SECRET_KEY").


%% token parameters
-define(UP_EXPIRES, 3600).
-define(DOWN_EXPIRES, 3600).
-define(PUTPOLICY, [<<"callbackUrl">>, <<"callbackBody">>, <<"callbackHost">>, <<"callbackBodyType">>, <<"callbackFetchKey">>,
	<<"returnUrl">>, <<"returnBody">>,
	<<"endUser">>, <<"saveKey">>, <<"insertOnly">>,<<"deleteAfterDays">>,
	<<"detectMime">>, <<"mimeLimit">>, <<"fsizeLimit">>, <<"fsizeMin">>,
	<<"persistenOps">>, <<"persistentNotifyUrl">>, <<"persistentPipeline">>]).

-define(EXAMPLE_PUTPOLICY, [{<<"callbackUrl">>, <<"http://1.1.1.1">>},{<<"insertOnly">>,1}]).
-define(DEF_PUTPOLICY, []).
-define(DEF_KEY, []).



%% others
%% 4MB
-define(BLOCK_SIZE, 4194304).

