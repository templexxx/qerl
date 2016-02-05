%%%-------------------------------------------------------------------
%%% @author templex
%%% @copyright (C) 2015, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 08. Nov 2015 9:47 AM
%%%-------------------------------------------------------------------
-module(auth).
-author("templex").

-include("config.hrl").

-import(utils, [urlsafe_base64_encode/1]).

%% API

-export([upload_token/1, upload_token/2, upload_token/3]).
-export([private_download_url/1, private_download_url/2]).
-export([verify_callback/3, verify_callback/4]).
-export([urlparse/1]).
-export([requests_auth/1, requests_auth/3]).


upload_token(Bucket) ->
    upload_token(Bucket, ?DEF_KEY, ?DEF_PUTPOLICY).
upload_token(Bucket, Key) ->
    upload_token(Bucket, Key, ?DEF_PUTPOLICY).
upload_token(Bucket, Key, PutPolicy) ->
    Right_PutPolicy = maps:without(?PUTPOLICY, maps:from_list(PutPolicy)),
    if
        Right_PutPolicy =:= #{} ->
            URLbase64_PutPolicy = urlsafe_base64_encode(putpolicy(Bucket, Key, PutPolicy)),
            sign(URLbase64_PutPolicy, 1) ++ ":" ++ URLbase64_PutPolicy;
        Right_PutPolicy =/= #{} ->
            io:format("Please give me the FUCKING correct putpolicy ")
    end.


private_download_url(URL) ->
    private_download_url(URL, ?DOWN_EXPIRES).
private_download_url(URL, Down_Expires) ->
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


requests_auth(URL) ->
    requests_auth(URL, [], ?DEF_CONTENT_TYPE).
requests_auth(URL, Body, Content_type) ->
    "QBox " ++ token_of_request(URL, Body, Content_type, 1).


%%%%%↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑%%%%%
%%%%%↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑ YOU NEED CARE ABOUT ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑%%%%%
%%%%%                                                                                                    %%%%%
%%%%%                                                                                                    %%%%%
%%%%%↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ Internal Fuctions ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓%%%%%
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


urlparse(URL) ->
    {ok, {_, _, _, _, P, Q}} = http_uri:parse(URL),
    {P, Q}.


token_of_request(URL, Body, Content_type, Num_key) ->
    {Path, Query} = urlparse(URL),
    if
        Content_type =:= ?DEF_CONTENT_TYPE ->
            sign(Path ++ Query ++ "\n" ++ Body, Num_key);
        true ->
            sign(Path ++ Query ++ "\n", 1)
    end.










