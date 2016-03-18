%%%-------------------------------------------------------------------
%%% @author templex
%%% @copyright (C) 2015, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 02. Dec 2015 10:19 AM
%%%-------------------------------------------------------------------
-module(qnhttp).
-author("templex").

-include("config.hrl").
-import(qnauth, [requests_auth/1, requests_auth/3]).

%% API
-export([req/3, req/4, req/5]).


%% 分别代表两种http请求方式post和get

%% 它们的返回为{StatusCode, Headers, Response}
%% 即 状态码 头部  响应体
%% 具体返回情况请参看h_response这个function

%% 在(StatusCode div 100 == 5) and (StatusCode =/= 579) or (StatusCode == 996)这个情况下
%% 将会进行?DEF_RETRY_TIME 的重试


req(Method, URL, ReqHeaders) ->
    req(Method, URL, ReqHeaders, <<>>).
req(Method, URL, ReqHeaders, ReqBody) ->
    req(Method, URL, ReqHeaders, ReqBody, ?DEF_CONTENT_TYPE).
req(Method, URL, ReqHeaders, ReqBody, ContentType) ->
    Resp = req_main(Method, URL, ReqHeaders, ReqBody, ContentType),
    case Resp of
        {error, Reason} -> {error, Reason};
        {StatusCode, RespHeaders, RespBody} ->
            retry(lists:seq(1, ?DEF_RETRY_TIME), StatusCode, RespHeaders, RespBody,
                Method, URL, ReqHeaders, ReqBody, ContentType)
    end.


%%%%%↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑%%%%%
%%%%%↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑ YOU NEED CARE ABOUT ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑%%%%%
%%%%%                                                                                                    %%%%%
%%%%%                                                                                                    %%%%%
%%%%%↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ Internal Functions ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓%%%%%
%%%%%↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓%%%%%


req_main(Method, URL, ReqHeaders, ReqBody, ContentType) ->
    if
        Method == get ->
            ReqsGet = {URL, ReqHeaders},
            RespGet = httpc:request(get, ReqsGet, ?DEF_OPTION, []),
            case RespGet of
                {error, Reason} -> {error, Reason};
                {ok, {{_, StatusCode, _}, RespHeaders, RespBody}} ->
                    {StatusCode, RespHeaders, RespBody}
            end;
        true ->
            ReqsPost = {URL, ReqHeaders, ContentType, ReqBody},
            RespPost = httpc:request(post, ReqsPost, ?DEF_OPTION, []),
            case RespPost of
                {error, Reason} -> {error, Reason};
                {ok, {{_, StatusCode, _}, RespHeaders, RespBody}} ->
                    {StatusCode, RespHeaders, RespBody}
            end
    end.


retry([], StatusCode, RespHeaders, Body, _, _, _, _, _) ->
    parse_resp(StatusCode, RespHeaders, Body);
retry([_|T], StatusCode, RespHeaders, RespBody, Method, URL, ReqHeaders, ReqBody, ContentType) ->
    case (StatusCode div 100 == 5) and (StatusCode =/= 579) or (StatusCode == 996) of
        true ->
            Resp = req_main(Method, URL, ReqHeaders, ReqBody, ContentType),
            case Resp of
                {error, Reason} -> {error, Reason};
                {StatusCode, RespHeaders, RespBody} ->
                    retry(T, StatusCode, RespHeaders, RespBody,
                        Method, URL, ReqHeaders, ReqBody, ContentType)
            end;
        false ->
            parse_resp(StatusCode, RespHeaders, RespBody)
end.


parse_resp(StatusCode, RespHeaders, RespBody) ->
    if
        RespBody == <<>> ->
            if
                StatusCode >= 300 -> {StatusCode, lists:last(RespHeaders), <<>>};
                true -> {StatusCode, <<>>, <<>>}
            end;
        true ->
            if
                StatusCode >= 300 -> {StatusCode, lists:last(RespHeaders), jsx:decode(binary:list_to_bin(RespBody))};
                true ->  {StatusCode, <<>>, jsx:decode(binary:list_to_bin(RespBody))}
            end
    end.