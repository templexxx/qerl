%%%-------------------------------------------------------------------
%%% @author templex
%%% @copyright (C) 2015, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 02. Dec 2015 10:19 AM
%%%-------------------------------------------------------------------
-module(http).
-author("templex").

-include("config.hrl").
-import(auth, [requests_auth/1, requests_auth/3]).

%% API
-export([h_post/4]).
-export([h_get/2]).

%% 分别代表两种http请求方式post和get

%% 它们的返回为{Status_code, Headers, Response}
%% 即 状态码 头部  响应体
%% 具体返回情况请参看h_response这个function

%% 在(Status_code div 100 == 5) and (Status_code =/= 579) or (Status_code == 996)这个情况下
%% 将会进行?DEF_RETRY_TIME 的重试

h_post(URL, Request_body, Headers, Content_type) ->
    {Status_code, Head, Body} = request(post, URL, Request_body, Headers, Content_type),
    retry(lists:seq(1, ?DEF_RETRY_TIME), Status_code, Head, Body, post, URL, Request_body, Headers, Content_type).

h_get(URL, Headers) ->
    {Status_code, Head, Body} = request(get, URL, [], Headers, []),
    retry(lists:seq(1, ?DEF_RETRY_TIME), Status_code, Head, Body, get, URL, [], Headers, []).


%%%%%↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑%%%%%
%%%%%↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑ YOU NEED CARE ABOUT ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑%%%%%
%%%%%                                                                                                    %%%%%
%%%%%                                                                                                    %%%%%
%%%%%↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ Internal Fuctions ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓%%%%%
%%%%%↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓%%%%%


h_response(Status_code, Head, Body) ->
    if
        Body == [] ->
            if
                Status_code >= 300 -> {Status_code, lists:last(Head), []};
            true -> {Status_code, [], []}
            end;
        true ->
            if
                Status_code >= 300 -> {Status_code, lists:last(Head), jsx:decode(binary:list_to_bin(Body))};
                true ->  {Status_code, [], jsx:decode(binary:list_to_bin(Body))}
            end
    end.


request(Method, URL, Request_body, Headers, Content_type) ->
    if
        Method == get ->
            case httpc:request(Method, {URL, Headers},
                                [{connect_timeout, timer:seconds(?DEF_CONNECT_TIMEOUT)}],[]) of
                {error,_} -> {0, [error], <<"{\"failed\":\"connect\"}">>};
                {ok, {{_, Status_code, _}, Head, Body}} -> {Status_code, Head, Body};
                _ ->  {0, [error], <<"{\"failed\":\"noresponse\"}">>}
            end;
        true ->
            case httpc:request(Method, {URL, Headers, Content_type, Request_body},
                                [{connect_timeout, timer:seconds(?DEF_CONNECT_TIMEOUT)}],[]) of
                {error,_} -> {0, [error], <<"{\"failed\":\"connect\"}">>};
                {ok, {{_, Status_code, _}, Head, Body}} -> {Status_code, Head, Body};
                _ -> {0, [error], <<"{\"failed\":\"noresponse\"}">>}
            end
    end.

retry([], Status_code, Head, Body, _, _, _, _, _) ->
    h_response(Status_code, Head, Body);
retry([_|T], Status_code, Head, Body, Method, URL, Request_body, Headers, Content_type) ->
    case (Status_code div 100 == 5) and (Status_code =/= 579) or (Status_code == 996) of
        true ->
            {Status_code_retry, Head_retry, Body_retry} = request(Method, URL, Request_body, Headers, Content_type),
            retry(T, Status_code_retry, Head_retry, Body_retry, Method, URL, Request_body, Headers, Content_type);
        false ->
            h_response(Status_code, Head, Body)
end.