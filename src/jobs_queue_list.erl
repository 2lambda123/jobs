%%==============================================================================
%% Copyright 2010 Erlang Solutions Ltd.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%% http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%==============================================================================

%%-------------------------------------------------------------------
%% File    : jobs_queue.erl
%% @author  : Ulf Wiger <ulf.wiger@erlang-solutions.com>
%% @end
%% Description : 
%%
%% Created : 15 Jan 2010 by Ulf Wiger <ulf.wiger@erlang-solutions.com>
%%-------------------------------------------------------------------

-module(jobs_queue_list).
-author('ulf.wiger@erlang-solutions.com').
-copyright('Erlang Solutions Ltd.').

-export([new/2,
         delete/1]).
-export([in/3,
         out/2,
         info/2,
         all/1,
         empty/1,
         is_empty/1,
         timedout/1, timedout/2]).

-include("jobs.hrl").
-import(jobs_lib, [timestamp/0]).

%-type timestamp() :: integer().
-type job()       :: {pid(), reference()}.
-type entry()     :: {timestamp(), job()}.


new(Options, Q) ->
    case proplists:get_value(type, Options, lifo) of
	lifo -> Q#queue{st = []}
    end.

delete(#queue{}) -> true.

-spec in(timestamp(), job(), #queue{}) -> #queue{}.
%%
%% Enqueue a job reference; return the updated queue
%%
in(TS, Job, #queue{st = []} = Q) ->
    Q#queue{st = [{TS, Job}], oldest_job = TS};
in(TS, Job, #queue{st = L} = Q) ->
    Q#queue{st = [{TS, Job} | L]}.

-spec out(N :: integer(), #queue{}) -> {[entry()], #queue{}}.
%%
%% Dequeue a batch of N jobs; return the modified queue.
%%
out(N, #queue{st = L, oldest_job = OJ} = Q) when N >= 0 ->
    {Out, Rest} = split(N, L),
    OJ1 = case Rest of
	      [] -> undefined;
	      _  -> OJ
	  end,
    {Out, Q#queue{st = Rest, oldest_job = OJ1}}.

split(N, L) ->
    split(N, L, []).

split(_, [], Acc) ->
    {lists:reverse(Acc), []};
split(N, [H|T], Acc) when N > 0 ->
    split(N-1, T, [H|Acc]);
split(0, T, Acc) ->
    {lists:reverse(Acc), T}.




-spec all(#queue{}) -> [entry()].
%%
%% Return all the job entries in the queue
%%
all(#queue{st = L}) ->
    L.


-type info_item() :: max_time | oldest_job | length.

-spec info(info_item(), #queue{}) -> any().
%%
%% Return information about the queue.
%%
info(max_time  , #queue{max_time = T}   ) -> T;
info(oldest_job, #queue{oldest_job = OJ}) -> OJ;
info(length    , #queue{st = L}) ->
    length(L).
    
-spec timedout(#queue{}) -> [entry()].
%%
%% Return all entries that have been in the queue longer than MaxTime.
%%
timedout(#queue{max_time = undefined}) -> [];
timedout(#queue{max_time = TO} = Q) ->
    timedout(TO, Q).

timedout(_ , #queue{oldest_job = undefined}) -> [];
timedout(TO, #queue{st = L} = Q) ->
    Now = timestamp(),
    {Left, Timedout} = lists:splitwith(fun({TS,_}) ->
					       not(is_expired(TS,Now,TO)) 
				       end, L),
    OJ = get_oldest_job(Left),
    {Timedout, Q#queue{oldest_job = OJ, st = Left}}.

get_oldest_job([]) -> undefined;
get_oldest_job(L) ->
    element(1, hd(lists:reverse(L))).


-spec is_empty(#queue{}) -> boolean().
%%
%% Check whether the queue is empty.
%%
is_empty(#queue{st = []}) -> true;
is_empty(_) ->
    false.

empty(#queue{} = Q) ->
    Q#queue{oldest_job = undefined, st = []}.

is_expired(TS, Now, TO) ->
    MS = Now - TS,
    MS > TO.

	


