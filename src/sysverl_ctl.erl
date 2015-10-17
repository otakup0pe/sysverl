-module(sysverl_ctl).
-export([stop/1, rpc_stop/0, status/1, rpc_status/0, hotload/1]).

rpc_status() -> {ok, ok}.

stop([Host]) ->
    case call(Host, sysverl_ctl, rpc_stop, []) of
        error -> erlang:halt(1);
        ok -> p_block_until_stopped(Host)
    end.

p_block_until_stopped(Host) -> p_block_until_stopped(Host, 30).
p_block_until_stopped(_Host, 0) -> erlang:halt(1);
p_block_until_stopped(Host, I) ->
    case net_adm:ping(Host) of
        pong ->
            timer:sleep(1000),
            p_block_until_stopped(Host, I - 1);
        pang -> erlang:halt(0)
    end.

rpc_stop() ->
    case catch heart:get_cmd() of
        {ok, _Cmd} -> heart:set_cmd("true");
        _ -> ok
    end,
    init:stop(),
    {ok, ok}.

status([Host]) ->
    case call(Host, sysverl_ctl, rpc_status, []) of
        ok -> 
	    erlang:halt(0);
        _ -> 
	    erlang:halt(1)
    end.

hotload([Host]) ->
    case call(Host, hotbeam, all, []) of
	ok ->
	    erlang:halt(0);
	_ ->
	    erlang:halt(1)
    end.

call(Host, M, F, A) ->
    case rpc:call(Host, M, F, A, 5000) of
        {ok, Value} ->
            Value;
    	{badrpc, E} ->
    	    error;
    	{error, E} -> 
    	    error
    end.
