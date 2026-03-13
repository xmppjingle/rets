-module(rets).
-behaviour(gen_server).

-export([start/0, start_link/0]).
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

-type db() :: atom().
-type key() :: term().
-type value() :: term().
-type field() :: term().

-spec start() -> {ok, pid()} | {error, term()}.
start() ->
    gen_server:start({local, ?MODULE}, ?MODULE, [], []).

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init(_Args) ->
    {ok, #{}}.

handle_call({create, DB}, _From, S) ->
    try
        ets:new(DB, [set, named_table, public]),
        {reply, ok, S#{DB => true}}
    catch
        error:badarg ->
            {reply, {error, already_exists}, S}
    end;
handle_call(_, _From, S) ->
    {reply, ok, S}.

handle_cast(_, S) ->
    {noreply, S}.

handle_info({'ETS-TRANSFER', _Table, _PID, _D}, S) ->
    {noreply, S};
handle_info(_, S) ->
    {noreply, S}.

code_change(_, _, S) ->
    {ok, S}.

terminate(_, _S) ->
    ok.

-spec init_db(db()) -> ok | {error, already_exists}.
init_db(DB) when is_atom(DB) ->
    gen_server:call(?MODULE, {create, DB}).

-spec set(db(), key(), value()) -> true.
set(DB, Key, Value) ->
    ets:insert(DB, {Key, Value}).

-spec get(db(), key()) -> value() | undefined.
get(DB, Key) ->
    case ets:lookup(DB, Key) of
        [{_, Value}|_] -> Value;
        _ -> undefined
    end.

-spec hgetall(db(), key()) -> map() | undefined.
hgetall(DB, Key) -> get(DB, Key).

-spec hget(db(), key(), field()) -> value() | undefined.
hget(DB, Key, Field) ->
    case get(DB, Key) of
        #{Field := Value} -> Value;
        _ -> undefined
    end.

-spec hlen(db(), key()) -> non_neg_integer().
hlen(DB, Key) ->
    case get(DB, Key) of
        #{} = M -> maps:size(M);
        _ -> 0
    end.

-spec hset(db(), key(), field(), value()) -> non_neg_integer().
hset(DB, Key, Field, Value) ->
    NMap = case get(DB, Key) of
        Map when is_map(Map) -> Map#{Field => Value};
        _ -> #{Field => Value}
    end,
    _ = set(DB, Key, NMap),
    maps:size(NMap).

-spec hdel(db(), key(), field()) -> non_neg_integer().
hdel(DB, Key, Field) ->
    case get(DB, Key) of
        Map when is_map(Map) ->
            case maps:is_key(Field, Map) of
                false ->
                    maps:size(Map);
                true ->
                    NewMap = maps:remove(Field, Map),
                    case map_size(NewMap) of
                        0 ->
                            _ = del(DB, Key),
                            0;
                        Size ->
                            _ = set(DB, Key, NewMap),
                            Size
                    end
            end;
        _ -> 0
    end.

-spec del(db(), key()) -> true.
del(DB, Key) ->
    ets:delete(DB, Key).
