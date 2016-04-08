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
				up_main(FilePath, File, Bucket, Key, PutPolicy, FSize)
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


up_main(FilePath, File, Bucket, Key, PutPolicy, FSize) ->
	Token = up_token(Bucket, Key, PutPolicy),
	if
		FSize < ?TRIGGER * ?BLOCK_SIZE ->
			up_bin(File, Key, Token, FSize);
		true ->
			bput(FilePath, File, Key, Token, FSize, Bucket)
	end.


up_bin(File, Key, Token, FSize) ->
	case file:pread(File, 0, FSize) of
		{error, Reason} -> {error, Reason};
		{ok, Data} ->
			up_bin_main(Data, Key, Token)
	end.


bput(FilePath, File, Key, UpToken, FSize, Bucket) ->
	PoolSize = poolsize(),
	BlockNum = (FSize div ?BLOCK_SIZE)
		+ (case FSize rem ?BLOCK_SIZE of
			   0 ->
				   0;
			   _ ->
				   1
		   end),
	dets:open_file(bput, {file, "bput"}),
	Qetag = utils:qetag(FilePath),
	CtxInfo = dets:lookup(bput, {Bucket, Qetag}),
	BlockTotal = lists:seq(0, BlockNum - 1),
	case CtxInfo of
		[] ->
			ctx_workers(File, FSize, PoolSize, UpToken, BlockTotal, Qetag, 0, BlockNum),
			CtxTuple = update_ctx([], BlockNum, 0, Bucket),
			CtxAllRaw = get_ctx(CtxTuple),
			CtxAll = string:strip(CtxAllRaw, left, $,),
			dets:close(bput),
			mkfile(Key, FSize, UpToken, CtxAll);
		[{_, CtxAlready}] ->
			BlockDoneList = block_done_list(CtxAlready, []),
			BlockLeftList = BlockTotal -- BlockDoneList,
			BlockDone = length(CtxAlready),
			case BlockDone == BlockNum of
				true ->
					KeyInQiniu =
						case Key == [] of
							true ->
								Qetag;
							false ->
								Key
						end,
					{StatusCodes, _, _} = bucket:stat(Bucket, KeyInQiniu),
					case StatusCodes of
						200 ->
							{"already exists", Qetag};
						_ ->
							ctx_workers(File, FSize, PoolSize, UpToken, BlockTotal, Qetag, BlockDone, BlockNum),
							CtxTuple = update_ctx([], BlockNum, 0, Bucket),
							CtxAllRaw = get_ctx(CtxTuple),
							CtxAll = string:strip(CtxAllRaw, left, $,),
							dets:close(bput),
							mkfile(Key, FSize, UpToken, CtxAll)
					end;
				false ->
					ctx_workers(File, FSize, PoolSize, UpToken, BlockLeftList, Qetag, BlockDone, BlockNum),
					CtxTuple = update_ctx(CtxAlready, BlockNum, BlockDone, Bucket),
					CtxAllRaw = get_ctx(CtxTuple),
					CtxAll = string:strip(CtxAllRaw, left, $,),
					dets:close(bput),
					mkfile(Key, FSize, UpToken, CtxAll)
			end
	end.

get_ctx(CtxList) ->
	SortCtx = lists:sort(CtxList),
	get_ctx_main(SortCtx, []).

get_ctx_main([], CtxAll) ->
	CtxAll;
get_ctx_main([H|T], CtxAll) ->
	{_, Ctx} = H,
	CtxUpdate = CtxAll ++ "," ++ Ctx,
	get_ctx_main(T, CtxUpdate).

block_done_list([], BlockDoneList) ->
	BlockDoneList;
block_done_list([H|T], BlockDoneList) ->
	{No_block, _} = H,
	BdlUpdate = BlockDoneList ++ [No_block - 1],
	block_done_list(T, BdlUpdate).


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


start_worker(Parent, File, Offset, Size, UpToken, Qetag, WhichBlock) ->
	{ok, BlockData} = file:pread(File, Offset, Size),
	Parent ! {ctx, ctx(BlockData, UpToken, Size), Qetag, WhichBlock}.



update_ctx(CtxAlready, BlockNum, BlockDone, Bucket)
	when BlockDone < BlockNum ->
	receive
		{ctx, CtxBlock, Qetag, WhickBlock} ->
			case CtxBlock of
				[] ->
					update_ctx(CtxAlready, BlockNum, BlockDone + 1, Bucket);
				_ ->
					CtxUpdate = CtxAlready ++ [{WhickBlock, CtxBlock}],
					dets:insert(bput, {{Bucket, Qetag}, CtxUpdate}),
					update_ctx(CtxUpdate, BlockNum, BlockDone + 1, Bucket)
			end
	end;
update_ctx(Ctx, BlockNum, BlockNum, _Bucket) ->
	Ctx.


ctx_workers(File, FSize, PoolSize, UpToken, BlockLeftList, Qetag, BlockDone, BlockNum) ->
	spawn_link(
		?MODULE,
		ctx_worker_pool,
		[self(), File, FSize, PoolSize, UpToken, BlockLeftList, Qetag, BlockDone, BlockNum]).


ctx_worker_pool(Parent, File, FSize, PoolSize, UpToken, BlockLeftList, Qetag, BlockDone, BlockNum) ->
	process_flag(trap_exit, true),
	worker_pool(
		#{parent => Parent,
			file => File,
			block_size => ?BLOCK_SIZE,
			file_size => FSize,
			worker_pool_size => PoolSize,
			file_offset => lists_first(BlockLeftList) * ?BLOCK_SIZE,
			next_block => lists_first(BlockLeftList),
			block_list => BlockLeftList -- [lists_first(BlockLeftList)],
			workers => 0,
			up_token =>  UpToken,
			qetag => Qetag,
			worker_pids => sets:new(),
			block_done => BlockDone,
			block_num => BlockNum}).

lists_first([]) ->
	[];
lists_first([H|_T]) ->
	H.

worker_pool(
		#{
			next_block := [],
			workers := 0}) ->
	ok;
worker_pool(
		State = #{
			next_block := []}) ->
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
		block_list := BlockLeftList,
		qetag := Qetag,
		block_done := BlockDone,
		block_num := BlockNum,
		worker_pids := Pids}) ->
	Pid = spawn_link(?MODULE, start_worker, [Parent, File, Offset, Size, UpToken, Qetag, NextBlock + 1]),
	worker_pool(
		State#{
			block_list := BlockLeftList -- [lists_first(BlockLeftList)],
			next_block := lists_first(BlockLeftList),
			block_done := BlockDone + 1,
			block_num := BlockNum,
			file_offset := (NextBlock * ?BLOCK_SIZE) + Size,
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
		{error, _Reason} -> [];
		{StatusCode, _RespHeaders, RespBody} ->
			if
				StatusCode == 200 ->
					[{_, Ctx}, _, _, _, _, _] = RespBody,
					binary_to_list(Ctx);
				true ->
					[]
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