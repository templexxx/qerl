%%%-------------------------------------------------------------------
%%% @author templex
%%% @copyright (C) 2015, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 03. Dec 2015 10:23 PM
%%%-------------------------------------------------------------------
-module(pfop).
-author("templex").

-include("config.hrl").
-import(http, [h_post/4]).
-import(qnauth, [requests_auth/3]).

%% API
-export([pfop/3, pfop/4, pfop/5, pfop/6]).


pfop(Bucket, Key, Fops) ->
    pfop(Bucket, Key, Fops, []).
pfop(Bucket, Key, Fops, NotifyURL) ->
    pfop(Bucket, Key, Fops, NotifyURL, []).
pfop(Bucket, Key, Fops, NotifyURL, Force) ->
    pfop(Bucket, Key, Fops, NotifyURL, Force, []).
pfop(Bucket, Key, Fops, NotifyURL, Force, Pipeline) ->
    Request_body = pfop_request_body(Bucket, Key, Fops, NotifyURL, Force, Pipeline),
    URL = ?API_HOST ++ "/pfop/",
    AUTH = requests_auth(URL, Request_body, ?DEF_CONTENT_TYPE),
    Headers = [{"Authorization", AUTH}],
    h_post(URL, Request_body, Headers, ?DEF_CONTENT_TYPE).


%%%%%↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑%%%%%
%%%%%↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑ YOU NEED CARE ABOUT ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑%%%%%
%%%%%                                                                                                    %%%%%
%%%%%                                                                                                    %%%%%
%%%%%↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ Internal Functions ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓%%%%%
%%%%%↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓%%%%%


pfop_request_body(Bucket, Key, Fops, NotifyURL, Force, Pipeline) ->
    Pipeline1 = pipeline(Pipeline),
    Force1 = force(Force),
    NotifyURL1 = notifyurl(NotifyURL),
    "bucket=" ++ http_uri:encode(Bucket) ++ "&key=" ++ http_uri:encode(Key) ++ "&fops=" ++ http_uri:encode(Fops) ++ NotifyURL1 ++ Force1 ++ Pipeline1.


pipeline(Pipeline) ->
    if
        Pipeline == [] -> [];
        true -> "&pipeline=" ++ http_uri:encode(Pipeline)
    end.


force(Force) ->
    if
        Force == [] ->  [] ;
        true -> "&force=" ++ Force
    end.


notifyurl(NotifyURL) ->
    if
        NotifyURL == [] -> [];
        true -> "&notifyURL=" ++ http_uri:encode(NotifyURL)
    end.





