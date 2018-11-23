-module(rets).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2]).
-export([terminate/2, handle_info/2, code_change/3]).

-export([
    init_db/1,
    set/3,
    get/2,
    hset/4,
    hget/3,
    hgetall/2,
    hlen/2,
    hdel/3,
    del/2]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init(_Args) ->
    {ok, #{}}.

handle_call({create, DB}, From, S) ->
    spawn(ets, new, [DB, [set, named_table, public, {heir, self(), S}]]),
    {reply, ok, S#{DB => From}};

handle_call(_, _From, S) ->
    {reply, ok, S}.

handle_cast(_, S) ->
    {noreply, S}.

handle_info(_, S) ->
    {noreply, S}.

code_change(_, _, S) ->
    {ok, S}.

terminate(_, _S) ->
    ok.

init_db(DB) when is_atom(DB) ->
    gen_server:call(?MODULE, {create, DB}).

set(DB, Key, Value) ->
    ets:insert(DB, {Key, Value}).

get(DB, Key) ->
    case ets:lookup(DB, Key) of
        [{_, Value}|_] -> Value;
        _ -> undefined
    end.

hgetall(DB, Key) -> get(DB,Key).

hget(DB, Key, Field) ->
    case get(DB, Key) of
        #{Field := Value} -> Value;
        _ -> undefined
    end.

hlen(DB, Key) ->
    case get(DB, Key) of
        #{} = M -> maps:size(M);
        _ -> 0
    end.

hset(DB, Key, Field, Value) ->
    NMap = case get(DB, Key) of
        Map when is_map(Map) -> Map#{Field => Value};
        _ -> #{Field => Value}
    end,
    set(DB, Key, NMap),
    maps:size(NMap).
    
hdel(DB, Key, Field) ->
    case get(DB, Key) of
        Map when is_map(Map) -> 
            NMap = case maps:remove(Field, Map) of                
                #{} = M when map_size(M) == 0 -> 
                    del(DB, Key), #{};
                Map -> 
                    Map;
                R ->
                    set(DB, Key, R), R
            end,
            maps:size(NMap);
        _ -> 0
    end.      

del(DB, Key) -> 
    ets:delete(DB, Key).
