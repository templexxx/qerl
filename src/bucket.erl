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

-import(http, [h_post/4, h_get/2]).
-import(utils, [entry/1, entry/2]).
-import(qnauth, [requests_auth/3]).

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
    AUTH = requests_auth(URL, [], ?DEF_CONTENT_TYPE),
    Headers = [{"Authorization", AUTH}],
    h_post(URL, [], Headers, ?DEF_CONTENT_TYPE).


stat(Bucket, Key) ->
    EncodedEntryURI = entry(Bucket, Key),
    URL = ?RS_HOST ++ "/stat/" ++ EncodedEntryURI,
    AUTH = requests_auth(URL, [], ?DEF_CONTENT_TYPE),
    Headers = [{"Authorization", AUTH}],
    h_get(URL, Headers).


move(Src_bukcet, Src_key, Dest_bucket, Dest_key) ->
    EncodedEntryURISrc = entry(Src_bukcet, Src_key),
    EncodedEntryURIDest = entry(Dest_bucket, Dest_key),
    URL = ?RS_HOST ++ "/move/" ++ EncodedEntryURISrc ++ "/" ++ EncodedEntryURIDest,
    AUTH = requests_auth(URL, [], ?DEF_CONTENT_TYPE),
    Headers = [{"Authorization", AUTH}],
    h_post(URL, [], Headers, ?DEF_CONTENT_TYPE).


copy(Src_bukcet, Src_key, Dest_bucket, Dest_key) ->
    EncodedEntryURISrc = entry(Src_bukcet, Src_key),
    EncodedEntryURIDest = entry(Dest_bucket, Dest_key),
    URL = ?RS_HOST ++ "/copy/" ++ EncodedEntryURISrc ++ "/" ++ EncodedEntryURIDest,
    AUTH = requests_auth(URL, [], ?DEF_CONTENT_TYPE),
    Headers = [{"Authorization", AUTH}],
    h_post(URL, [], Headers, ?DEF_CONTENT_TYPE).


delete(Bucket, Key) ->
    EncodedEntryURI = entry(Bucket, Key),
    URL = ?RS_HOST ++ "/delete/" ++ EncodedEntryURI,
    AUTH = requests_auth(URL, [], ?DEF_CONTENT_TYPE),
    Headers = [{"Authorization", AUTH}],
    h_post(URL, [], Headers, ?DEF_CONTENT_TYPE).


fetch(Src_URL, Bucket, Key) ->
    EncodedEntryURI = entry(Bucket, Key),
    EncodedSrcURL = urlsafe_base64_encode(Src_URL),
    URL = ?IO_HOST ++ "/fetch/" ++ EncodedSrcURL ++ "/to/" ++ EncodedEntryURI,
    AUTH = requests_auth(URL, [], ?DEF_CONTENT_TYPE),
    Headers = [{"Authorization", AUTH}],
    h_post(URL, [], Headers, ?DEF_CONTENT_TYPE).


chgm(Bucket, Key, MimeType) ->
    URL = ?RS_HOST ++ "/chgm/" ++ entry(Bucket, Key) ++ "/mime/" ++ entry(MimeType),
    AUTH = requests_auth(URL, [], ?DEF_CONTENT_TYPE),
    Headers = [{"Authorization", AUTH}],
    h_post(URL, [], Headers, ?DEF_CONTENT_TYPE).


prefetch(Bucket, Key) ->
    URL = ?IO_HOST ++ "/prefetch/" ++ entry(Bucket, Key),
    AUTH = requests_auth(URL, [], ?DEF_CONTENT_TYPE),
    Headers = [{"Authorization", AUTH}],
    h_post(URL, [], Headers, ?DEF_CONTENT_TYPE).


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
    AUTH = requests_auth(URL, Ops, ?DEF_CONTENT_TYPE),
    Headers = [{"Authorization", AUTH}],
    h_post(URL, Ops, Headers, ?DEF_CONTENT_TYPE).


%%%%%↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑%%%%%
%%%%%↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑ YOU NEED CARE ABOUT ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑%%%%%
%%%%%                                                                                                    %%%%%
%%%%%                                                                                                    %%%%%
%%%%%↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ Internal Fuctions ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓%%%%%
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


