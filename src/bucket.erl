%%%-------------------------------------------------------------------
%%% @author templex
%%% @copyright (C) 2015, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 01. Dec 2015 5:35 PM
%%%-------------------------------------------------------------------
-module(bucket).
-author("templex").

-include("config.hrl").

-import(utils, [urlsafe_base64_encode/1]).

-import(qnhttp, [req/3, req/4]).
-import(utils, [entry/1, entry/2]).
-import(qnauth, [auth_request/3]).

%% API
-export([list/1, list/2, list/3, list/4, list/5]).
-export([stat/2]).
-export([move/4]).
-export([copy/4]).
-export([delete/2]).
-export([fetch/3]).
-export([chgm/3]).
-export([prefetch/2]).
-export([batch_stat/1]).
-export([batch_move/1]).
-export([batch_copy/1]).
-export([batch_delete/1]).
-export([batch/1]).


list(Bucket) ->
    list(Bucket, []).
list(Bucket, Marker) ->
    list(Bucket, Marker, []).
list(Bucket, Marker, Limit) ->
    list(Bucket, Marker, Limit, []).
list(Bucket, Marker, Limit, Prefix) ->
    list(Bucket, Marker, Limit, Prefix, []).
list(Bucket, Marker, Limit, Prefix, Delimiter) ->
    URL = list_url(Bucket, Marker, Limit, Prefix, Delimiter),
    AUTH = auth_request(URL, [], ?DEF_CONTENT_TYPE),
    ReqReqHeaders = [{"Authorization", AUTH}],
    req(post, URL, ReqReqHeaders).


stat(Bucket, Key) ->
    EncodedEntryURI = entry(Bucket, Key),
    URL = ?RS_HOST ++ "/stat/" ++ EncodedEntryURI,
    AUTH = auth_request(URL, [], ?DEF_CONTENT_TYPE),
    ReqHeaders = [{"Authorization", AUTH}],
    req(get, URL, ReqHeaders).


move(Src_bukcet, Src_key, Dest_bucket, Dest_key) ->
    EncodedEntryURISrc = entry(Src_bukcet, Src_key),
    EncodedEntryURIDest = entry(Dest_bucket, Dest_key),
    URL = ?RS_HOST ++ "/move/" ++ EncodedEntryURISrc ++ "/" ++ EncodedEntryURIDest,
    AUTH = auth_request(URL, [], ?DEF_CONTENT_TYPE),
    ReqHeaders = [{"authorization", AUTH}],
    req(post, URL, ReqHeaders).


copy(Src_bukcet, Src_key, Dest_bucket, Dest_key) ->
    EncodedEntryURISrc = entry(Src_bukcet, Src_key),
    EncodedEntryURIDest = entry(Dest_bucket, Dest_key),
    URL = ?RS_HOST ++ "/copy/" ++ EncodedEntryURISrc ++ "/" ++ EncodedEntryURIDest,
    AUTH = auth_request(URL, [], ?DEF_CONTENT_TYPE),
    ReqHeaders = [{"authorization", AUTH}],
    req(post, URL, ReqHeaders).


delete(Bucket, Key) ->
    EncodedEntryURI = entry(Bucket, Key),
    URL = ?RS_HOST ++ "/delete/" ++ EncodedEntryURI,
    AUTH = auth_request(URL, [], ?DEF_CONTENT_TYPE),
    ReqHeaders = [{"authorization", AUTH}],
    req(post, URL, ReqHeaders).


fetch(Src_URL, Bucket, Key) ->
    EncodedEntryURI = entry(Bucket, Key),
    EncodedSrcURL = urlsafe_base64_encode(Src_URL),
    URL = ?IO_HOST ++ "/fetch/" ++ EncodedSrcURL ++ "/to/" ++ EncodedEntryURI,
    AUTH = auth_request(URL, [], ?DEF_CONTENT_TYPE),
    ReqHeaders = [{"authorization", AUTH}],
    req(post, URL, ReqHeaders).


chgm(Bucket, Key, MimeType) ->
    URL = ?RS_HOST ++ "/chgm/" ++ entry(Bucket, Key) ++ "/mime/" ++ entry(MimeType),
    AUTH = auth_request(URL, [], ?DEF_CONTENT_TYPE),
    ReqHeaders = [{"authorization", AUTH}],
    req(post, URL, ReqHeaders).


prefetch(Bucket, Key) ->
    URL = ?IO_HOST ++ "/prefetch/" ++ entry(Bucket, Key),
    AUTH = auth_request(URL, [], ?DEF_CONTENT_TYPE),
    ReqHeaders = [{"authorization", AUTH}],
    req(post, URL, ReqHeaders).


batch_stat(Key_list) ->
    batch_Op_1("stat", Key_list).


batch_delete(Key_list) ->
    batch_Op_1("delete", Key_list).


batch_move(Key_list) ->
    batch_Op_2("move", Key_list).


batch_copy(Key_list) ->
    batch_Op_2("copy", Key_list).


batch(Ops) ->
    URL = ?RS_HOST ++ "/batch",
    AUTH = auth_request(URL, Ops, ?DEF_CONTENT_TYPE),
    ReqHeaders = [{"authorization", AUTH}],
    req(post, URL, ReqHeaders, list_to_binary(Ops)).


%%%%%↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑%%%%%
%%%%%↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑ YOU NEED CARE ABOUT ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑%%%%%
%%%%%                                                                                                    %%%%%
%%%%%                                                                                                    %%%%%
%%%%%↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ Internal Functions ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓%%%%%
%%%%%↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓%%%%%


list_url(Bucket, Marker, Limit, Prefix, Delimiter) ->
    Delimiter1 = delimiter(Delimiter),
    Prefix1 = prefix(Prefix),
    Limit1 = limit(Limit),
    Marker1 = marker(Marker),
    ?RSF_HOST ++ "/list?bucket=" ++ Bucket ++Marker1 ++ Limit1 ++ Prefix1 ++ Delimiter1.


delimiter(Delimiter) ->
    if
        Delimiter == [] ->  [];
        true -> "&delimiter=" ++ http_uri:encode(Delimiter)
    end.


prefix(Prefix) ->
    if
        Prefix == [] -> [] ;
        true -> "&prefix=" ++ http_uri:encode(Prefix)
    end.


limit(Limit) ->
    if
        Limit == [] -> [];
        true -> "&limit=" ++ Limit
    end.

marker(Marker) ->
    if
        Marker == [] -> [];
        true -> "&marker=" ++ Marker
    end.


batch_Op_1(Op,Key_list) ->
    batch_Op_1([], Op, Key_list).
batch_Op_1(Ops, _, []) ->
    batch(string:strip(Ops, left, $&));
batch_Op_1(Ops, Op, [H|T]) ->
    {Bucket, Key} = H,
    Op1 = "&op=/" ++ Op ++ "/" ++ entry(Bucket, Key),
    OPS = Op1 ++ Ops,
    batch_Op_1(OPS, Op, T).


batch_Op_2(Op,Key_list) ->
    batch_Op_2([], Op, Key_list).
batch_Op_2(Ops, _, []) ->
    batch(string:strip(Ops, left, $&));
batch_Op_2(Ops, Op, [H|T]) ->
    {Src_bucket, Src_key, Dest_bucket, Dest_key} = H,
    Op1 = "&op=/" ++ Op ++ "/" ++ entry(Src_bucket, Src_key) ++ "/" ++ entry(Dest_bucket, Dest_key),
    OPS = Op1 ++ Ops,
    batch_Op_2(OPS, Op, T).


