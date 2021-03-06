%%% @author Jean Parpaillon <jean.parpaillon@free.fr>
%%% @copyright (C) 2013, Jean Parpaillon
%%% 
%%% This file is provided to you under the Apache License,
%%% Version 2.0 (the "License"); you may not use this file
%%% except in compliance with the License.  You may obtain
%%% a copy of the License at
%%% 
%%%   http://www.apache.org/licenses/LICENSE-2.0
%%% 
%%% Unless required by applicable law or agreed to in writing,
%%% software distributed under the License is distributed on an
%%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%%% KIND, either express or implied.  See the License for the
%%% specific language governing permissions and limitations
%%% under the License.
%%% 
%%% @doc
%%%
%%% @end
%%% Created :  1 Jul 2013 by Jean Parpaillon <jean.parpaillon@free.fr>
-module(occi_backend).
-behaviour(gen_server).

-compile([{parse_transform, lager_transform}]).

-include("occi.hrl").
%% API
-export([start_link/1]).
-export([update/2,
	 save/2,
	 delete/2,
	 find/2,
	 load/2,
	 action/3,
	 cast/3,
	 cancel/2]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3]).

-record(state, {ref             :: atom(),
		mod             :: atom(),
		state           :: term(),
		pending         :: term()}).

-callback init(Backend :: occi_backend()) ->
    {ok, State :: term()} |
    {error, Reason :: term()}.

-callback terminate(State :: term()) ->
    term().

-callback update(Node :: occi_node(), State :: term()) ->
    {ok, State :: term()} |
    {{error, Reason :: term()}, State :: term()}.

-callback save(Node :: occi_node() | occi_mixin(), State :: term()) ->
    {ok, State :: term()} |
    {{error, Reason :: term()}, State :: term()}.

-callback delete(Node :: occi_node() | occi_mixin(), State :: term()) ->
    {ok, State :: term()} |
    {{error, Reason :: term()}, State :: term()}.

-callback find(Request :: occi_node() | occi_mixin(), State :: term()) ->
    {{ok, [occi_node()]}, term()} |
    {{error, Reason :: term()}, State :: term()}.

-callback load(Node :: occi_node(), State :: term()) ->
    {{ok, occi_node()}, term()} |
    {{error, Reason :: term()}, State :: term()}.

-callback action({Id :: uri(), Action :: occi_action()}, State :: term()) ->
    {ok, term()} |
    {{error, Reason :: term()}, State :: term()}.

%%%
%%% API
%%% 
-spec start_link(occi_backend()) -> {ok, pid()} | ignore | {error, term()}.
start_link(#occi_backend{ref=Ref, mod=Mod}=Backend) ->
    lager:info("Starting storage backend ~p (~p)~n", [Ref, Mod]),
    gen_server:start_link({local, Ref}, ?MODULE, Backend, []).

update(Ref, Node) ->
    gen_server:call(Ref, {update, Node}).

save(Ref, Obj) ->
    gen_server:call(Ref, {save, Obj}).

delete(Ref, Obj) ->
    gen_server:call(Ref, {delete, Obj}).

find(Ref, Request) ->
    gen_server:call(Ref, {find, Request}).

load(Ref, Request) ->
    gen_server:call(Ref, {load, Request}).

action(Ref, Id, Action) ->
    gen_server:call(Ref, {action, {Id, Action}}).

cast(Ref, Op, Req) ->
    gen_server:call(Ref, {cast, Op, Req}).

cancel(Ref, Tag) ->
    gen_server:cast(Ref, {cancel, Tag}).

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
-spec init(occi_backend()) -> {ok, term()} | {error, term()} | ignore.
init(#occi_backend{ref=Ref, mod=Mod}=Backend) ->
    T = ets:new(Mod, [set, public, {keypos, 1}]),
    case Mod:init(Backend) of
	{ok, BackendState} ->
	    {ok, #state{ref=Ref, mod=Mod, pending=T, state=BackendState}};
	{error, Error} ->
	    {stop, Error}
    end.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @spec handle_call(Request, From, State) ->
%%                                   {reply, Reply, State} |
%%                                   {reply, Reply, State, Timeout} |
%%                                   {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, Reply, State} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_call({cast, Op, Req}, {Pid, Tag}, #state{mod=Mod, pending=T, state=BState}=State) ->
    ets:insert(T, {Tag, Pid}),
    F = fun () ->
		{Reply, _} = Mod:Op(Req, BState),
		case ets:match_object(T, {Tag, '_'}) of
		    [] ->
			% Operation canceled
			ok;
		    [{Tag, Pid}] ->
			Pid ! {Tag, Reply},
			ets:delete(T, Tag)
		end
	end,
    spawn(F),
    {reply, Tag, State#state{state=BState}};

handle_call({Op, Request}, _From, #state{mod=Mod, state=BState}=State) ->
    {Reply, RState} = Mod:Op(Request, BState),
    {reply, Reply, State#state{mod=Mod, state=RState}};

handle_call(Req, From, State) ->
    lager:error("Unknown message from ~p: ~p~n", [From, Req]),
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_cast({cancel, Tag}, #state{pending=T}=State) ->
    ets:delete(T, Tag),
    {noreply, State};

handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, #state{pending=T, mod=Mod, state=State}) ->
    ets:delete(T),
    Mod:terminate(State).

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

