%%%-------------------------------------------------------------------
%%% @author templex
%%% @copyright (C) 2015, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 08. Nov 2015 9:47 AM
%%%-------------------------------------------------------------------
-module(qnauth).
-author("templex").

-include("config.hrl").

-import(utils, [urlsafe_base64_encode/1]).

%% API

-export([up_token/1, up_token/2, up_token/3]).
-export([private_url/1, private_url/2]).
-export([verify_callback/3, verify_callback/4]).
-export([parse_url/1]).
-export([auth_request/1, auth_request/3]).


up_token(Bucket) ->
    up_token(Bucket, ?DEF_KEY, ?DEF_PUTPOLICY).
up_token(Bucket, Key) ->
    up_token(Bucket, Key, ?DEF_PUTPOLICY).
up_token(Bucket, Key, PutPolicy) ->
    IS_putpolicy = maps:without(?PUTPOLICY, maps:from_list(PutPolicy)),
    if
        IS_putpolicy =:= #{} ->
            Safe_policy = urlsafe_base64_encode(putpolicy(Bucket, Key, PutPolicy)),
            sign(Safe_policy, 1) ++ ":" ++ Safe_policy;
        IS_putpolicy =/= #{} ->
            io:format("Please give me the FUCKING correct putpolicy ")
    end.


private_url(URL) ->
    private_url(URL, ?DOWN_EXPIRES).
private_url(URL, Down_Expires) ->
    DownloadURL = URL ++ "?e=" ++ integer_to_list(expires_time(Down_Expires)),
    DownloadURL ++ "&token=" ++ sign(DownloadURL, 1).


verify_callback(Origin_authorization, URL, Body) ->
    verify_callback(Origin_authorization, URL, Body, ?DEF_CONTENT_TYPE).
verify_callback(Origin_authorization, URL, Body, Content_type) ->
    AK_part = string:substr(Origin_authorization, 6, 5),
    AK1_part = string:substr(?AK1, 1, 5),
    if
        AK_part =:= AK1_part ->
            Origin_authorization =:= "QBox " ++ token_of_request(URL, Body, Content_type, 1);
        true ->
            Origin_authorization =:= "QBox " ++ token_of_request(URL, Body, Content_type, 2)

    end.


auth_request(URL) ->
    auth_request(URL, [], ?DEF_CONTENT_TYPE).
auth_request(URL, Body, Content_type) ->
    "QBox " ++ token_of_request(URL, Body, Content_type, 1).


%%%%%↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑%%%%%
%%%%%↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑ YOU NEED CARE ABOUT ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑%%%%%
%%%%%                                                                                                    %%%%%
%%%%%                                                                                                    %%%%%
%%%%%↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ Internal Functions ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓%%%%%
%%%%%↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓%%%%%


expires_time(Expires) ->
    {M, S, _} = os:timestamp(),
    Expires + 1000000 * M  + S.


putpolicy(Bucket, Key, PutPolicy) ->
    Deadline = [{<<"deadline">>, expires_time(?UP_EXPIRES)}],
    Scope_string = string:strip(Bucket ++ ":" ++ Key, right, $:),
    Scope = [{<<"scope">>,
            binary:list_to_bin(Scope_string)}],
    binary:bin_to_list(jsx:encode
                        (lists:append
                          (lists:append(PutPolicy, Deadline), Scope))).


sign(Data, Num_key) ->
    if
        Num_key =:= 1 ->
            ?AK1 ++ ":" ++ urlsafe_base64_encode(crypto:hmac(sha, ?SK1, Data));
        true ->
            ?AK2 ++ ":" ++ urlsafe_base64_encode(crypto:hmac(sha, ?SK2, Data))
    end.


parse_url(URL) ->
    {ok, {_, _, _, _, P, Q}} = http_uri:parse(URL),
    {P, Q}.


token_of_request(URL, Body, Content_type, Num_key) ->
    {Path, Query} = parse_url(URL),
    if
        Content_type =:= ?DEF_CONTENT_TYPE ->
            sign(Path ++ Query ++ "\n" ++ Body, Num_key);
        true ->
            sign(Path ++ Query ++ "\n", 1)
    end.










