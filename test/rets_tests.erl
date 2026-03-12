-module(rets_tests).
-include_lib("eunit/include/eunit.hrl").

%% ============================================================
%% Test fixture: start/stop rets gen_server for each test
%% ============================================================

setup() ->
    {ok, Pid} = rets:start_link(),
    Pid.

teardown(Pid) ->
    unlink(Pid),
    exit(Pid, shutdown),
    timer:sleep(10).

unique_db(Base) ->
    Ref = erlang:unique_integer([positive]),
    list_to_atom(atom_to_list(Base) ++ "_" ++ integer_to_list(Ref)).

%% ============================================================
%% Test generator
%% ============================================================

rets_test_() ->
    {foreach,
     fun setup/0,
     fun teardown/1,
     [
         fun test_init_db/1,
         fun test_init_db_duplicate/1,
         fun test_set_get/1,
         fun test_get_undefined/1,
         fun test_set_overwrite/1,
         fun test_del/1,
         fun test_del_nonexistent/1,
         fun test_hset_hget/1,
         fun test_hset_multiple_fields/1,
         fun test_hget_missing_field/1,
         fun test_hget_nonexistent_key/1,
         fun test_hgetall/1,
         fun test_hgetall_nonexistent/1,
         fun test_hlen/1,
         fun test_hlen_nonexistent/1,
         fun test_hlen_non_map/1,
         fun test_hdel/1,
         fun test_hdel_last_field/1,
         fun test_hdel_nonexistent_field/1,
         fun test_hdel_nonexistent_key/1,
         fun test_multiple_dbs/1,
         fun test_set_various_types/1
     ]}.

gen_server_test_() ->
    {foreach,
     fun setup/0,
     fun teardown/1,
     [
         fun test_unknown_call/1,
         fun test_unknown_cast/1,
         fun test_unknown_info/1,
         fun test_code_change/1
     ]}.

%% ============================================================
%% init_db tests
%% ============================================================

test_init_db(_Pid) ->
    DB = unique_db(init_db),
    fun() ->
        ?assertEqual(ok, rets:init_db(DB)),
        %% Table should be usable immediately (race condition fix)
        ?assertEqual(true, rets:set(DB, key1, value1)),
        ?assertEqual(value1, rets:get(DB, key1))
    end.

test_init_db_duplicate(_Pid) ->
    DB = unique_db(init_db_dup),
    fun() ->
        ?assertEqual(ok, rets:init_db(DB)),
        ?assertEqual({error, already_exists}, rets:init_db(DB))
    end.

%% ============================================================
%% set/get tests
%% ============================================================

test_set_get(_Pid) ->
    DB = unique_db(set_get),
    fun() ->
        rets:init_db(DB),
        ?assertEqual(true, rets:set(DB, mykey, myvalue)),
        ?assertEqual(myvalue, rets:get(DB, mykey))
    end.

test_get_undefined(_Pid) ->
    DB = unique_db(get_undef),
    fun() ->
        rets:init_db(DB),
        ?assertEqual(undefined, rets:get(DB, nonexistent))
    end.

test_set_overwrite(_Pid) ->
    DB = unique_db(set_overwrite),
    fun() ->
        rets:init_db(DB),
        rets:set(DB, k, v1),
        ?assertEqual(v1, rets:get(DB, k)),
        rets:set(DB, k, v2),
        ?assertEqual(v2, rets:get(DB, k))
    end.

%% ============================================================
%% del tests
%% ============================================================

test_del(_Pid) ->
    DB = unique_db(del),
    fun() ->
        rets:init_db(DB),
        rets:set(DB, k, v),
        ?assertEqual(v, rets:get(DB, k)),
        ?assertEqual(true, rets:del(DB, k)),
        ?assertEqual(undefined, rets:get(DB, k))
    end.

test_del_nonexistent(_Pid) ->
    DB = unique_db(del_nonexist),
    fun() ->
        rets:init_db(DB),
        ?assertEqual(true, rets:del(DB, nonexistent))
    end.

%% ============================================================
%% hset/hget tests
%% ============================================================

test_hset_hget(_Pid) ->
    DB = unique_db(hset_hget),
    fun() ->
        rets:init_db(DB),
        ?assertEqual(1, rets:hset(DB, hash1, field1, val1)),
        ?assertEqual(val1, rets:hget(DB, hash1, field1))
    end.

test_hset_multiple_fields(_Pid) ->
    DB = unique_db(hset_multi),
    fun() ->
        rets:init_db(DB),
        ?assertEqual(1, rets:hset(DB, h, f1, v1)),
        ?assertEqual(2, rets:hset(DB, h, f2, v2)),
        ?assertEqual(3, rets:hset(DB, h, f3, v3)),
        ?assertEqual(v1, rets:hget(DB, h, f1)),
        ?assertEqual(v2, rets:hget(DB, h, f2)),
        ?assertEqual(v3, rets:hget(DB, h, f3))
    end.

test_hget_missing_field(_Pid) ->
    DB = unique_db(hget_miss),
    fun() ->
        rets:init_db(DB),
        rets:hset(DB, h, f1, v1),
        ?assertEqual(undefined, rets:hget(DB, h, no_such_field))
    end.

test_hget_nonexistent_key(_Pid) ->
    DB = unique_db(hget_nokey),
    fun() ->
        rets:init_db(DB),
        ?assertEqual(undefined, rets:hget(DB, nokey, nofield))
    end.

%% ============================================================
%% hgetall tests
%% ============================================================

test_hgetall(_Pid) ->
    DB = unique_db(hgetall),
    fun() ->
        rets:init_db(DB),
        rets:hset(DB, h, f1, v1),
        rets:hset(DB, h, f2, v2),
        ?assertEqual(#{f1 => v1, f2 => v2}, rets:hgetall(DB, h))
    end.

test_hgetall_nonexistent(_Pid) ->
    DB = unique_db(hgetall_nokey),
    fun() ->
        rets:init_db(DB),
        ?assertEqual(undefined, rets:hgetall(DB, nokey))
    end.

%% ============================================================
%% hlen tests
%% ============================================================

test_hlen(_Pid) ->
    DB = unique_db(hlen),
    fun() ->
        rets:init_db(DB),
        rets:hset(DB, h, f1, v1),
        rets:hset(DB, h, f2, v2),
        ?assertEqual(2, rets:hlen(DB, h))
    end.

test_hlen_nonexistent(_Pid) ->
    DB = unique_db(hlen_nokey),
    fun() ->
        rets:init_db(DB),
        ?assertEqual(0, rets:hlen(DB, nokey))
    end.

test_hlen_non_map(_Pid) ->
    DB = unique_db(hlen_nonmap),
    fun() ->
        rets:init_db(DB),
        rets:set(DB, k, <<"not a map">>),
        ?assertEqual(0, rets:hlen(DB, k))
    end.

%% ============================================================
%% hdel tests
%% ============================================================

test_hdel(_Pid) ->
    DB = unique_db(hdel),
    fun() ->
        rets:init_db(DB),
        rets:hset(DB, h, f1, v1),
        rets:hset(DB, h, f2, v2),
        ?assertEqual(1, rets:hdel(DB, h, f1)),
        ?assertEqual(undefined, rets:hget(DB, h, f1)),
        ?assertEqual(v2, rets:hget(DB, h, f2))
    end.

test_hdel_last_field(_Pid) ->
    DB = unique_db(hdel_last),
    fun() ->
        rets:init_db(DB),
        rets:hset(DB, h, f1, v1),
        ?assertEqual(0, rets:hdel(DB, h, f1)),
        %% Key should be deleted entirely
        ?assertEqual(undefined, rets:get(DB, h))
    end.

test_hdel_nonexistent_field(_Pid) ->
    DB = unique_db(hdel_nofield),
    fun() ->
        rets:init_db(DB),
        rets:hset(DB, h, f1, v1),
        rets:hset(DB, h, f2, v2),
        ?assertEqual(2, rets:hdel(DB, h, no_such_field))
    end.

test_hdel_nonexistent_key(_Pid) ->
    DB = unique_db(hdel_nokey),
    fun() ->
        rets:init_db(DB),
        ?assertEqual(0, rets:hdel(DB, nokey, nofield))
    end.

%% ============================================================
%% Multi-DB and type tests
%% ============================================================

test_multiple_dbs(_Pid) ->
    DB1 = unique_db(multi_db1),
    DB2 = unique_db(multi_db2),
    fun() ->
        rets:init_db(DB1),
        rets:init_db(DB2),
        rets:set(DB1, k, v1),
        rets:set(DB2, k, v2),
        ?assertEqual(v1, rets:get(DB1, k)),
        ?assertEqual(v2, rets:get(DB2, k))
    end.

test_set_various_types(_Pid) ->
    DB = unique_db(types),
    fun() ->
        rets:init_db(DB),
        %% Atom keys/values
        rets:set(DB, atom_key, atom_val),
        ?assertEqual(atom_val, rets:get(DB, atom_key)),
        %% Binary keys/values
        rets:set(DB, <<"bin_key">>, <<"bin_val">>),
        ?assertEqual(<<"bin_val">>, rets:get(DB, <<"bin_key">>)),
        %% Integer keys/values
        rets:set(DB, 42, 100),
        ?assertEqual(100, rets:get(DB, 42)),
        %% Tuple keys/values
        rets:set(DB, {a, b}, {c, d}),
        ?assertEqual({c, d}, rets:get(DB, {a, b})),
        %% List values
        rets:set(DB, list_key, [1, 2, 3]),
        ?assertEqual([1, 2, 3], rets:get(DB, list_key))
    end.

%% ============================================================
%% Gen_server behavioral tests
%% ============================================================

test_unknown_call(_Pid) ->
    fun() ->
        ?assertEqual(ok, gen_server:call(rets, {unknown, message}))
    end.

test_unknown_cast(_Pid) ->
    fun() ->
        ?assertEqual(ok, gen_server:cast(rets, {unknown, cast})),
        %% Ensure process is still alive
        ?assert(is_pid(whereis(rets)))
    end.

test_unknown_info(_Pid) ->
    fun() ->
        rets ! {unknown, info, message},
        %% Ensure process is still alive
        timer:sleep(10),
        ?assert(is_pid(whereis(rets)))
    end.

test_code_change(_Pid) ->
    fun() ->
        State = #{some => state},
        ?assertEqual({ok, State}, rets:code_change(old_vsn, ignored, State))
    end.
