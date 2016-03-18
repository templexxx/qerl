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


-import(qnauth, [up_token/1, up_token/2, up_token/3]).
-import(qnhttp, [req/4, req/5]).
-import(utils, [urlsafe_base64_encode/1]).


%% API
-export([up/2, up/3, up/4]).
-compile(export_all).


up(FilePath, Bucket) ->
	up(FilePath, Bucket, []).
up(FilePath, Bucket, Key) ->
	up(FilePath, Bucket, Key, []).
up(FilePath, Bucket, Key, PutPolicy) ->
	case file:open(FilePath, [read, binary]) of
		{error, Reason} -> {error, Reason};
		{ok, File} ->
			{ok, FSize} = file:position(File, eof),
			try
				up_main(File, Bucket, Key, PutPolicy, FSize)
			after
				file:close(File)
			end

	end.


%%%%%↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑%%%%%
%%%%%↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑ YOU NEED CARE ABOUT ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑%%%%%
%%%%%                                                                                                    %%%%%
%%%%%                                                                                                    %%%%%
%%%%%↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ Internal Functions ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓%%%%%
%%%%%↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓%%%%%


up_main(File, Bucket, Key, PutPolicy, FSize) ->
	Token = up_token(Bucket, Key, PutPolicy),
	if
		FSize < ?TRIGGER * ?BLOCK_SIZE ->
			up_bin(File, Key, Token, FSize);
		true ->
			bput(File, Key, Token, FSize)
	end.


up_bin(File, Key, Token, FSize) ->
	case file:pread(File, 0, FSize) of
		{error, Reason} -> {error, Reason};
		{ok, Data} ->
			up_bin_main(Data, Key, Token)
	end.


bput(File, Key, UpToken, FSize) ->
	PoolSize = poolsize(),
	BlockNum = (FSize div ?BLOCK_SIZE)
		+ (case FSize rem ?BLOCK_SIZE of
			   0 ->
				   0;
			   _ ->
				   1
		   end),
	ctx_workers(File, FSize, PoolSize, UpToken),
	CtxAllRaw = update_ctx([], BlockNum, 0),
	CtxAll = string:strip(CtxAllRaw, left, $,),
	mkfile(Key, FSize, UpToken, CtxAll).


%%%%%↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ Internal Functions ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓%%%%%
%%%%%↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓%%%%%


up_bin_main(Data, Key, Token) ->
	Data_list = binary_to_list(Data),
	Boundary = "------------thatiscoolboundaryisnotit",
	ReqBody = format_multipart_body(Boundary, Token, Key, Data_list),
	ContentType = lists:concat(["multipart/form-data; boundary=", Boundary]),
	ReqHeaders = [{"content-length", length(ReqBody)}],
	req(post, ?UP_HOST, ReqHeaders, ReqBody, ContentType).


format_multipart_body(Boundary, Token, Key, Data_list) ->
	if
		Key == [] ->
			format_multipart_body_main(Boundary, [{token, Token}], [{file, "file", Data_list}]);
		true ->
			format_multipart_body_main(Boundary, [{token, Token}, {key, Key}], [{file, "file", Data_list}])
	end.


format_multipart_body_main(Boundary, Fields, Files) ->
	FieldParts = lists:map(fun({FieldName, FieldContent}) ->
		[lists:concat(["--", Boundary]),
			lists:concat(["content-disposition: form-data; name=\"", atom_to_list(FieldName), "\""]),
			"",
			FieldContent]
	                       end, Fields),
	FieldParts2 = lists:append(FieldParts),
	FileParts = lists:map(fun({FieldName, FileName, FileContent}) ->
		[lists:concat(["--", Boundary]),
			lists:concat(["content-disposition: form-data; name=\"",
				atom_to_list(FieldName), "\"; filename=\"", FileName, "\""]),
			lists:concat(["content-type: ", "application/octet-stream"]),
			"",
			FileContent]
	                      end, Files),
	FileParts2 = lists:append(FileParts),
	EndingParts = [lists:concat(["--", Boundary, "--"]), ""],
	Parts = lists:append([FieldParts2, FileParts2, EndingParts]),
	string:join(Parts, "\r\n").


start_worker(Parent, File, BlockDoneNum, Offset, Size, UpToken) ->
	{ok, BlockData} = file:pread(File, Offset, Size),
	Parent ! {ctx, BlockDoneNum, ctx(BlockData, UpToken, Size)}.



update_ctx(Ctx, BlockNum, BlockDoneNum)
	when BlockDoneNum < BlockNum ->
	receive
		{ctx, BlockDoneNum, CtxBlock} ->
			update_ctx(
				Ctx ++ "," ++ CtxBlock,
				BlockNum,
				BlockDoneNum + 1
				)
	end;
update_ctx(Ctx, BlockNum, BlockNum) ->
	Ctx.


ctx_workers(File, FSize, PoolSize, UpToken) ->
	spawn_link(
		?MODULE,
		ctx_worker_pool,
		[self(), File, FSize, PoolSize, UpToken]).


ctx_worker_pool(Parent, File, FSize, PoolSize, UpToken) ->
	process_flag(trap_exit, true),
	worker_pool(
		#{ parent => Parent,
			file => File,
			block_size => ?BLOCK_SIZE,
			file_size => FSize,
			worker_pool_size => PoolSize,
			file_offset => 0,
			next_block => 0,
			workers => 0,
			up_token =>  UpToken,
			worker_pids => sets:new()}).


worker_pool(
		#{ file_offset := FileSize,
			file_size := FileSize,
			workers := 0}) ->
	ok;
worker_pool(
		State = #{
			file_offset := FileSize,
			file_size := FileSize}) ->
	receive
		{'EXIT', Pid, normal} ->
			worker_done(Pid, State)
	end;
worker_pool(
		State = #{
			workers := PoolSize,
			worker_pool_size := PoolSize}) ->
	receive
		{'EXIT', Pid, normal} ->
			worker_done(Pid, State)
	end;
worker_pool(
		State = #{
			file_offset := FileOffset,
			file_size := FSize,
			block_size := ?BLOCK_SIZE}
) when FileOffset + ?BLOCK_SIZE < FSize ->
	run_worker(FileOffset, ?BLOCK_SIZE, State);
worker_pool(
		State = #{
			file_offset := FileOffset,
			file_size := FSize}) ->
	run_worker(FileOffset, FSize - FileOffset, State).


run_worker(
		Offset, Size,
		State = #{
			parent := Parent,
			file := File,
			next_block := NextBlock,
			workers := Workers,
			up_token :=  UpToken,
			worker_pids := Pids}) ->
	Pid = spawn_link(?MODULE, start_worker, [Parent, File, NextBlock, Offset, Size, UpToken]),
	worker_pool(
		State#{
			next_block := NextBlock + 1,
			file_offset := Offset + Size,
			workers := Workers + 1,
			up_token :=  UpToken,
			worker_pids := sets:add_element(Pid, Pids)}).


worker_done(Pid, State = #{workers := Workers, worker_pids := Pids}) ->
	case sets:is_element(Pid, Pids) of
		true ->
			worker_pool(
				State#{workers := Workers - 1,
					worker_pids := sets:del_element(Pid, Pids)});
		false ->
			worker_pool(State)
	end.


poolsize() ->
	case ?THREAD_NUM of
		0 ->
			erlang:system_info(thread_pool_size);
		_ ->
			?THREAD_NUM
	end.


ctx(BlockData, UpToken, BlockSize) ->
	AUTH = "UpToken " ++ UpToken,
	ReqHeaders = [{"content-length", ?BLOCK_SIZE}, {"authorization", AUTH}],
	Resp = req(post, ?MKBLK_HOST ++ integer_to_list(BlockSize), ReqHeaders, BlockData, "application/octet-stream"),
	case Resp of
		{error, _Reason} -> "error";
		{StatusCode, _RespHeaders, RespBody} ->
			if
				StatusCode == 200 ->
					[{_, Ctx}, _, _, _, _, _] = RespBody,
					binary_to_list(Ctx);
				true ->
					"error"
			end
	end.


mkfile(Key, FSize, UpToken, Ctx) ->
	URL = mkfile_url(Key, FSize),
	AUTH = "UpToken " ++ UpToken,
	ReqHeaders = [{"content-Length", length(Ctx)}, {"authorization", AUTH}],
	req(post, URL, ReqHeaders, list_to_binary(Ctx), "text/plain").


mkfile_url(Key, FSize) ->
	if
		Key == [] -> ?UP_HOST ++ "/mkfile/" ++ integer_to_list(FSize);
		true -> ?UP_HOST ++ "/mkfile/" ++ integer_to_list(FSize) ++ "/key/" ++ urlsafe_base64_encode(Key)
	end.