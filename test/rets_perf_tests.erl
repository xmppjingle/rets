-module(rets_perf_tests).
-include_lib("eunit/include/eunit.hrl").

%% ============================================================
%% Performance / Benchmark Tests
%% ============================================================

setup() ->
    {ok, Pid} = rets:start_link(),
    Pid.

teardown(Pid) ->
    unlink(Pid),
    MRef = monitor(process, Pid),
    exit(Pid, shutdown),
    receive {'DOWN', MRef, process, Pid, _} -> ok
    after 5000 -> ok
    end.

unique_db(Base) ->
    Ref = erlang:unique_integer([positive]),
    list_to_atom(atom_to_list(Base) ++ "_" ++ integer_to_list(Ref)).

perf_test_() ->
    {foreach,
     fun setup/0,
     fun teardown/1,
     [
         fun test_set_get_throughput/1,
         fun test_hset_hget_throughput/1,
         fun test_concurrent_reads/1,
         fun test_concurrent_writes/1,
         fun test_concurrent_mixed/1,
         fun test_hdel_churn/1
     ]}.

%% ============================================================
%% Sequential set/get throughput: 100K ops
%% ============================================================

test_set_get_throughput(_Pid) ->
    DB = unique_db(perf_sg),
    N = 100000,
    {timeout, 60, fun() ->
        rets:init_db(DB),
        %% Write phase
        {WriteUs, _} = timer:tc(fun() ->
            lists:foreach(fun(I) -> rets:set(DB, I, I) end, lists:seq(1, N))
        end),
        %% Read phase
        {ReadUs, _} = timer:tc(fun() ->
            lists:foreach(fun(I) -> rets:get(DB, I) end, lists:seq(1, N))
        end),
        WriteOps = N * 1000000 / WriteUs,
        ReadOps = N * 1000000 / ReadUs,
        ?debugFmt("~nset/get ~p ops: write=~w ops/s, read=~w ops/s",
                  [N, round(WriteOps), round(ReadOps)]),
        %% Generous threshold: 100K ops in under 10s
        ?assert(WriteUs < 10000000),
        ?assert(ReadUs < 10000000)
    end}.

%% ============================================================
%% Sequential hset/hget throughput: 100K ops
%% ============================================================

test_hset_hget_throughput(_Pid) ->
    DB = unique_db(perf_hsg),
    N = 100000,
    {timeout, 60, fun() ->
        rets:init_db(DB),
        %% Write phase: spread across 100 hashes with 1000 fields each
        {WriteUs, _} = timer:tc(fun() ->
            lists:foreach(fun(I) ->
                Hash = I rem 100,
                rets:hset(DB, Hash, I, I)
            end, lists:seq(1, N))
        end),
        %% Read phase
        {ReadUs, _} = timer:tc(fun() ->
            lists:foreach(fun(I) ->
                Hash = I rem 100,
                rets:hget(DB, Hash, I)
            end, lists:seq(1, N))
        end),
        WriteOps = N * 1000000 / WriteUs,
        ReadOps = N * 1000000 / ReadUs,
        ?debugFmt("~nhset/hget ~p ops: write=~w ops/s, read=~w ops/s",
                  [N, round(WriteOps), round(ReadOps)]),
        ?assert(WriteUs < 30000000),
        ?assert(ReadUs < 10000000)
    end}.

%% ============================================================
%% Concurrent reads: 10 processes x 10K reads
%% ============================================================

test_concurrent_reads(_Pid) ->
    DB = unique_db(perf_cread),
    NumProcs = 10,
    OpsPerProc = 10000,
    {timeout, 60, fun() ->
        rets:init_db(DB),
        %% Pre-populate 1000 keys
        lists:foreach(fun(I) -> rets:set(DB, I, I) end, lists:seq(1, 1000)),
        Parent = self(),
        {Us, _} = timer:tc(fun() ->
            Pids = [spawn_link(fun() ->
                lists:foreach(fun(I) ->
                    rets:get(DB, (I rem 1000) + 1)
                end, lists:seq(1, OpsPerProc)),
                Parent ! {done, self()}
            end) || _ <- lists:seq(1, NumProcs)],
            lists:foreach(fun(P) ->
                receive {done, P} -> ok end
            end, Pids)
        end),
        TotalOps = NumProcs * OpsPerProc,
        Ops = TotalOps * 1000000 / Us,
        ?debugFmt("~nconcurrent reads (~p procs x ~p): ~w ops/s",
                  [NumProcs, OpsPerProc, round(Ops)]),
        ?assert(Us < 10000000)
    end}.

%% ============================================================
%% Concurrent writes: 10 processes x 10K writes
%% ============================================================

test_concurrent_writes(_Pid) ->
    DB = unique_db(perf_cwrite),
    NumProcs = 10,
    OpsPerProc = 10000,
    {timeout, 60, fun() ->
        rets:init_db(DB),
        Parent = self(),
        {Us, _} = timer:tc(fun() ->
            Pids = [spawn_link(fun() ->
                Base = ProcN * OpsPerProc,
                lists:foreach(fun(I) ->
                    rets:set(DB, Base + I, I)
                end, lists:seq(1, OpsPerProc)),
                Parent ! {done, self()}
            end) || ProcN <- lists:seq(1, NumProcs)],
            lists:foreach(fun(P) ->
                receive {done, P} -> ok end
            end, Pids)
        end),
        TotalOps = NumProcs * OpsPerProc,
        Ops = TotalOps * 1000000 / Us,
        ?debugFmt("~nconcurrent writes (~p procs x ~p): ~w ops/s",
                  [NumProcs, OpsPerProc, round(Ops)]),
        ?assert(Us < 10000000)
    end}.

%% ============================================================
%% Concurrent mixed: 5 readers + 5 writers x 10K ops each
%% ============================================================

test_concurrent_mixed(_Pid) ->
    DB = unique_db(perf_cmixed),
    NumReaders = 5,
    NumWriters = 5,
    OpsPerProc = 10000,
    {timeout, 60, fun() ->
        rets:init_db(DB),
        %% Pre-populate some keys for readers
        lists:foreach(fun(I) -> rets:set(DB, I, I) end, lists:seq(1, 1000)),
        Parent = self(),
        {Us, _} = timer:tc(fun() ->
            Writers = [spawn_link(fun() ->
                Base = W * OpsPerProc,
                lists:foreach(fun(I) ->
                    rets:set(DB, Base + I, I)
                end, lists:seq(1, OpsPerProc)),
                Parent ! {done, self()}
            end) || W <- lists:seq(1, NumWriters)],
            Readers = [spawn_link(fun() ->
                lists:foreach(fun(I) ->
                    rets:get(DB, (I rem 1000) + 1)
                end, lists:seq(1, OpsPerProc)),
                Parent ! {done, self()}
            end) || _ <- lists:seq(1, NumReaders)],
            lists:foreach(fun(P) ->
                receive {done, P} -> ok end
            end, Writers ++ Readers)
        end),
        TotalOps = (NumReaders + NumWriters) * OpsPerProc,
        Ops = TotalOps * 1000000 / Us,
        ?debugFmt("~nconcurrent mixed (~p readers + ~p writers x ~p): ~w ops/s",
                  [NumReaders, NumWriters, OpsPerProc, round(Ops)]),
        ?assert(Us < 10000000)
    end}.

%% ============================================================
%% hdel churn: 50K create/delete cycles
%% ============================================================

test_hdel_churn(_Pid) ->
    DB = unique_db(perf_hdel),
    N = 50000,
    {timeout, 60, fun() ->
        rets:init_db(DB),
        {Us, _} = timer:tc(fun() ->
            lists:foreach(fun(I) ->
                Hash = I rem 100,
                Field = I rem 50,
                rets:hset(DB, Hash, Field, I),
                rets:hdel(DB, Hash, Field)
            end, lists:seq(1, N))
        end),
        Ops = N * 2 * 1000000 / Us,
        ?debugFmt("~nhdel churn ~p cycles (~p ops): ~w ops/s",
                  [N, N * 2, round(Ops)]),
        ?assert(Us < 30000000)
    end}.
