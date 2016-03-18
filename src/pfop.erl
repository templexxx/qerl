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
-import(qnhttp, [req/4]).
-import(qnauth, [auth_request/3]).

%% API
-export([pfop/3, pfop/4, pfop/5, pfop/6]).


pfop(Bucket, Key, Fops) ->
    pfop(Bucket, Key, Fops, []).
pfop(Bucket, Key, Fops, NotifyURL) ->
    pfop(Bucket, Key, Fops, NotifyURL, []).
pfop(Bucket, Key, Fops, NotifyURL, Force) ->
    pfop(Bucket, Key, Fops, NotifyURL, Force, []).
pfop(Bucket, Key, Fops, NotifyURL, Force, Pipeline) ->
    ReqBody = pfop_request_body(Bucket, Key, Fops, NotifyURL, Force, Pipeline),
    URL = ?API_HOST ++ "/pfop/",
    AUTH = auth_request(URL, ReqBody, ?DEF_CONTENT_TYPE),
    ReqHeaders = [{"Authorization", AUTH}],
    req(post, URL, ReqHeaders, list_to_binary(ReqBody)).


%%%%%↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑%%%%%
%%%%%↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑ YOU NEED CARE ABOUT ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑%%%%%
%%%%%                                                                                                    %%%%%
%%%%%                                                                                                    %%%%%
%%%%%↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ Internal Functions ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓%%%%%
%%%%%↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓%%%%%


pfop_request_body(Bucket, Key, Fops, NotifyURL, Force, Pipeline) ->
    Pipeline1 = pipeline(Pipeline),
    Force1 = force(Force),
    NotifyURL1 = notify_url(NotifyURL),
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


notify_url(NotifyURL) ->
    if
        NotifyURL == [] -> [];
        true -> "&notifyURL=" ++ http_uri:encode(NotifyURL)
    end.





