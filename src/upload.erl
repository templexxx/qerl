%%%-------------------------------------------------------------------
%%% @author templex
%%% @copyright (C) 2015, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 03. Dec 2015 10:25 PM
%%%-------------------------------------------------------------------
-module(upload).
-author("templex").

-include("config.hrl").
-include_lib("kernel/include/file.hrl").

-import(qnauth, [upload_token/1, upload_token/2, upload_token/3]).
-import(http, [h_post/4]).
-import(utils, [urlsafe_base64_encode/1]).

-define(MKBLK_HOST, "http://up.qiniu.com/mkblk/4194304").

%% API
-export([up/2, up/3, up/4]).
-export([put_small_file/2, put_small_file/3, put_small_file/4]).
-export([put_bin/4]).
-export([bput/3, bput/4, bput/5]).


%% 上传操作
%% 对于Fsize >= 5 * ?BLOCK_SIZE 的情况，将执行分块上传
%% 其他情况执行表单上传

up(File_path, Bucket) ->
    up([], File_path, Bucket).
up(Putpolicy, File_path, Bucket) ->
    up(Putpolicy, File_path, Bucket, []).
up(Putpolicy, File_path, Bucket, Key) ->
    {ok, FInfo} = file:read_file_info(File_path),
    Fsize = FInfo#file_info.size,
    if
        Fsize >= 5 * ?BLOCK_SIZE ->
            {ok, File} = file:open(File_path, [read, binary]),
            try
                bput(Putpolicy, File, Bucket, Key, Fsize)
            after
                file:close(File)
            end;
        true -> put_small_file(Putpolicy, File_path, Bucket, Key)
    end.


%% 直接表单上传

put_small_file(File_path, Bucket) ->
    put_small_file([], File_path, Bucket).
put_small_file(Putpolicy, File_path, Bucket) ->
    put_small_file(Putpolicy, File_path, Bucket, []).
put_small_file(Putpolicy, File_path, Bucket, Key) ->
    {ok, Data_bin} = file:read_file(File_path),
    put(Putpolicy, Data_bin, Bucket, Key).

%% 表单上传binary

put_bin(Putpolicy, Data_bin, Bucket, Key) ->
    put(Putpolicy, Data_bin, Bucket, Key).

%% 分块上传

bput(File, Bucket, Fsize) ->
    bput([], File, Bucket, Fsize).
bput(Putpolicy, File, Bucket, Fsize) ->
    bput(Putpolicy, File, Bucket,[], Fsize).
bput(Putpolicy, File, Bucket, Key, Fsize) ->
    Uptoken = upload_token(Bucket, Key, Putpolicy),
    mkfile(File, Fsize, Key, Uptoken).



%%%%%↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑%%%%%
%%%%%↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑ YOU NEED CARE ABOUT ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑%%%%%
%%%%%                                                                                                    %%%%%
%%%%%                                                                                                    %%%%%
%%%%%↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ Internal Fuctions ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓%%%%%
%%%%%↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓%%%%%


put(Putpolicy, Data_bin, Bucket, Key) ->
    UP_token = upload_token(Bucket, Key, Putpolicy),
    Data = binary_to_list(Data_bin),
    Boundary = "------------a450glvjfEoqerAc1p431paQlfDac152cadADfd",
    Body = request_body(Boundary, UP_token, Key, Data),
    ContentType = lists:concat(["multipart/form-data; boundary=", Boundary]),
    Headers = [{"Content-Length", integer_to_list(length(Body))}],
    h_post(?UP_HOST, Body, Headers, ContentType).


request_body(Boundary, UP_token, Key, Data) ->
    if
        Key == [] -> format_multipart_formdata(Boundary, [{token, UP_token}], [{file, "file", Data}]);
        true ->  format_multipart_formdata(Boundary, [{token, UP_token}, {key, Key}], [{file, "file", Data}])
    end.


format_multipart_formdata(Boundary, Fields, Files) ->
    FieldParts = lists:map(fun({FieldName, FieldContent}) ->
        [lists:concat(["--", Boundary]),
        lists:concat(["Content-Disposition: form-data; name=\"",atom_to_list(FieldName),"\""]),
        "",
        FieldContent]
                         end, Fields),
    FieldParts2 = lists:append(FieldParts),
    FileParts = lists:map(fun({FieldName, FileName, FileContent}) ->
        [lists:concat(["--", Boundary]),
          lists:concat(["Content-Disposition: form-data; name=\"",atom_to_list(FieldName),"\"; filename=\"",FileName,"\""]),
          lists:concat(["Content-Type: ", "application/octet-stream"]),
          "",
          FileContent]
                          end, Files),
    FileParts2 = lists:append(FileParts),
    EndingParts = [lists:concat(["--", Boundary, "--"]), ""],
    Parts = lists:append([FieldParts2, FileParts2, EndingParts]),
    string:join(Parts, "\r\n").


mkfile(File, Fsize, Key, Uptoken) ->
   {Num_thread,  Num_blocks_in_rawblock, Num_blocks_in_lastsize, Start, Last_block_size} = get_num_thread(Fsize),
    First_part = combine_ctx([], lists:sort(ctx_list(File, Num_thread, Num_blocks_in_rawblock, Uptoken))),
    URL = mkfile_url(Key, Fsize),
    AUTH = "UpToken " ++ Uptoken,
    Request_body1 = string:strip(First_part, left, $,),
    if
        Num_blocks_in_lastsize == 0 ->
            Header = [{"Content-Length", length(Request_body1)}, {"Authorization", AUTH }],
            h_post(URL, Request_body1, Header, "text/plain");
        true ->
            if
                Last_block_size == 0 ->
                    Second_part = combine_ctx([], lists:sort(ctx_list_last(File, Num_blocks_in_lastsize + 1, Start, Uptoken))),
                    CTX_all = string:strip(First_part ++ Second_part, left, $,),
                    HEADers = [{"Content-Length", length(CTX_all)}, {"Authorization", AUTH }],
                    h_post(URL, CTX_all, HEADers, "text/plain");
                true ->
                    Second_part1 =
                    combine_ctx([], lists:sort(ctx_list_last(File, Num_blocks_in_lastsize , Start, Uptoken))),
                    CTX_all1 = First_part ++ Second_part1,
                    Headers = [{"Content-Length", integer_to_list(Last_block_size)}, {"Authorization", AUTH }],
                    {ok, FL} = file:pread(File, Fsize - Last_block_size, Last_block_size),
                    LAST_block_url = ?UP_HOST ++ "/mkblk/" ++ integer_to_list(Last_block_size),
                    {_, [], [{_,CTX3},_,_,_,_,_]} = h_post(LAST_block_url, FL, Headers, "application/octet-stream"),
                    CTX1 = binary_to_list(CTX3),
                    CTX_ALL = string:strip(CTX_all1 ++ "," ++ CTX1, left, $,),
                    HEADers = [{"Content-Length", integer_to_list(length(CTX_ALL))}, {"Authorization", AUTH }],
                    h_post(URL, CTX_ALL, HEADers, "text/plain")
            end
     end.


mkfile_url(Key, Fsize) ->
    if
        Key == [] -> ?UP_HOST ++ "/mkfile/" ++ integer_to_list(Fsize);
        true -> ?UP_HOST ++ "/mkfile/" ++ integer_to_list(Fsize) ++ "/key/" ++ urlsafe_base64_encode(Key)
    end.


get_num_thread(Fsize) ->
    PoolSize = erlang:system_info(thread_pool_size),
    Num_blocks_in_rawblock = Fsize div ?BLOCK_SIZE div PoolSize,
    Onetime_size = PoolSize * ?BLOCK_SIZE * Num_blocks_in_rawblock,
    Last_size = Fsize - Onetime_size,
    Num_blocks_in_lastsize = Last_size div ?BLOCK_SIZE,
    Last_block_size = (Last_size - Num_blocks_in_lastsize * ?BLOCK_SIZE),
    if
        Onetime_size == Fsize  ->
            {PoolSize - 1,  Num_blocks_in_rawblock - 1, 0, Num_blocks_in_rawblock * PoolSize, Last_block_size};
        true ->
            {PoolSize - 1,  Num_blocks_in_rawblock - 1, Num_blocks_in_lastsize, Num_blocks_in_rawblock * PoolSize, Last_block_size}
    end.


ctx_list(File, Num_thread, Num_blocks_in_rawblock, Uptoken) ->
    upmap(fun (Off) ->
        Read_start = Off * (Num_blocks_in_rawblock + 1),
        Read_off = Read_start + Num_blocks_in_rawblock,
        CTX_list_rawblock = get_rawblock_ctx_list(File, lists:seq(Read_start, Read_off), [], Uptoken),
        [{Off, CTX_list_rawblock}]
          end, lists:seq(0, Num_thread)).


ctx_list_last(File, Num_thread, Start, Uptoken)->
  upmap(fun (Off)->
      {ok, Fd_bs} = file:pread(File, (Off + Start) * ?BLOCK_SIZE, ?BLOCK_SIZE),
      CTX2 = "," ++ get_ctx(Fd_bs, Uptoken),
      [{Off, CTX2}]
        end, lists:seq(0, Num_thread-1)).


get_ctx(Bin, Uptoken) ->
    AUTH = "UpToken " ++ Uptoken,
    Headers = [{"Content-Length", ?BLOCK_SIZE}, {"Authorization", AUTH }],
    {_, [], [{_,CTX},_,_,_,_,_]} = h_post(?MKBLK_HOST, Bin, Headers, "application/octet-stream"),
    binary_to_list(CTX).



get_rawblock_ctx_list(_, [], Ctx_list, _) ->
    Ctx_list;
get_rawblock_ctx_list(File, [H|T], CTX_list, Uptoken) ->
    {ok, Fd_bs} = file:pread(File,  H * ?BLOCK_SIZE, ?BLOCK_SIZE),
    Ctx_list = CTX_list ++ "," ++ get_ctx(Fd_bs, Uptoken),
    get_rawblock_ctx_list(File,  T, Ctx_list, Uptoken).


upmap(F, L) ->
    Parent = self(),
    Ref = make_ref(),
    [receive {Ref, Result} ->
        Result ++ []
    end
        || _ <- [spawn(fun() -> Parent ! {Ref, F(X)} end) || X <- L]].


combine_ctx(CTX_LIST, []) ->
    CTX_LIST;
combine_ctx(CTX_list, [H|T]) ->
    [{_, CTX4}] = H,
    CTX_LIST = CTX_list ++  CTX4,
    combine_ctx(CTX_LIST, T).
