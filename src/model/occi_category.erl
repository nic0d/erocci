%%%-------------------------------------------------------------------
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
%%% @doc OCCI Category type
%%%
%%% @end
%%% Created : 27 Sep 2013 by Jean Parpaillon <jean.parpaillon@free.fr>
%%%-------------------------------------------------------------------
-module(occi_category).
-compile([{parse_transform, lager_transform}]).

-include("occi.hrl").

%% from occi_object
-export([destroy/1,
	 save/1]).

% specific
-export([new/2,
	 init/2,
	 get_id/1,
	 get_class/1,
	 get_scheme/1,
	 get_term/1,
	 get_title/1,
	 set_title/2,
	 add_attribute/2,
	 set_types_check/2]).

% specific implementations
-export([impl_get_scheme/1,
	 impl_get_term/1,
	 impl_get_title/1,
	 impl_set_title/2,
	 impl_add_attribute/2,
	 impl_set_types_check/2]).

-record(data, {super                :: term(),
	       scheme,
	       term,
	       title                :: binary(),
	       attributes           :: term()      % dict
	      }).

-define(super(X), X#data.obj).

%%
%% from occi_object
%%
destroy(Ref) -> 
    occi_object:destroy(Ref).

save(Ref) -> 
    occi_object:save(Ref).

%%
%% specific
%%
-spec new(atom(), term()) -> {global, reference()} | {error, term()}.
new(Mods, Args) ->
    Ref = make_ref(),
    Mods2 = lists:reverse([occi_category|Mods]),
    ChildSpec = {Ref, 
		 {gen_server, start_link, [{global, Ref}, occi_object, {Mods2, Args}, []]},
		 permanent, brutal_kill, worker, [occi_object|Mods2]},
    case supervisor:start_child(occi_category_mgr, ChildSpec) of
	{ok, _Child} ->
	    {global, Ref};
	{ok, _Child, _Info} ->
	    {global, Ref};
	{error, Err} ->
	    {error, Err}
    end.

init(Scheme, Term) ->
    #data{scheme=Scheme, term=Term, attributes=dict:new()}.

get_id(Ref) ->
    #occi_cid{scheme=get_scheme(Ref),
	      term=get_term(Ref),
	      class=get_class(Ref)}.

get_class(Ref) ->
    occi_object:call(Ref, impl_get_class, []).

get_scheme(Ref) ->
    occi_object:call(Ref, impl_get_scheme, []).

get_term(Ref)->
    occi_object:call(Ref, impl_get_term, []).

get_title(Ref) ->
    occi_object:call(Ref, impl_get_title, []).

set_title(Ref, Title) ->
    occi_object:call(Ref, impl_set_title, [Title]).

add_attribute(Ref, Attr) ->
    occi_object:call(Ref, impl_add_attribute, [Attr]).

set_types_check(Ref, Types) ->
    occi_object:call(Ref, impl_set_types_check, {Types}).

impl_get_scheme(#data{scheme=Scheme}=Data) ->
    {{ok, Scheme}, Data}.

impl_get_term(#data{term=Term}=Data) ->
    {{ok, Term}, Data}.

impl_get_title(#data{title=Title}=Data) ->
    {{ok, Title}, Data}.

impl_set_title(#data{}=Data, Title) ->
    {ok, Data#data{title=Title}}.

impl_add_attribute(#data{attributes=Attrs}=Data, A) ->
    Attrs2 = dict:store(occi_attribute:get_id(A), A, Attrs),
    {ok, Data#data{attributes=Attrs2}}.

impl_set_types_check(#data{}=Data, Types) ->
    Attrs = dict:map(fun (_Id, Attr) ->
			     occi_attribute:set_check(Attr, Types)
		     end, Data#data.attributes),
    {ok, Data#data{attributes=Attrs}}.
