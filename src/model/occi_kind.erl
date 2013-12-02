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
%%% Created : 25 Jul 2013 by Jean Parpaillon <jean.parpaillon@free.fr>
-module(occi_kind).
-compile([{parse_transform, lager_transform}]).

-include("occi.hrl").

%% from occi_object
-export([destroy/1,
	 save/1]).

%% from occi_category
-export([get_id/1,
	 get_class/1,
	 get_scheme/1,
	 get_term/1,
	 get_title/1,
	 set_title/2,
	 add_attribute/2,
	 set_types_check/2]).

-export([new/1,
	 new/2,
	 init/2,
	 get_parent/1,
	 set_parent/3,
	 get_actions/1,
	 add_action/2]).

%% specific implementations
-export([impl_get_class/1,
	 impl_get_parent/1,
	 impl_set_parent/3,
	 impl_get_actions/1,
	 impl_add_action/2]).

-record(data, {super            :: term(),
	       parent           :: occi_cid(),
	       actions    = []}).

%%
%% from occi_object
%%
destroy(Ref) -> 
    occi_category:destroy(Ref).

save(Ref) -> 
    occi_category:save(Ref).

%%
%% from occi_category
%%
get_id(Ref) -> 
    occi_category:get_id(Ref).

get_class(Ref) -> 
    occi_category:get_class(Ref).

get_scheme(Ref) -> 
    occi_category:get_scheme(Ref).

get_term(Ref) -> 
    occi_category:get_term(Ref).

get_title(Ref) -> 
    occi_category:get_title(Ref).

set_title(Ref, Title) -> 
    occi_category:set_title(Ref, Title).

add_attribute(Ref, A) -> 
    occi_category:add_attribute(Ref, A).

set_types_check(Ref, Types) -> 
    occi_category:set_types_check(Ref, Types).

%%
%% specific methods
%%
new({Scheme, Term}) ->
    new([], {Scheme, Term}).

new(Mods, {Scheme, Term}) ->
    occi_category:new(lists:reverse([?MODULE|Mods]), {Scheme, Term}).

init(Scheme, Term) ->
    Cat = occi_category:init(Scheme, Term),
    #data{super=Cat}.

get_parent(Ref) ->
    occi_object:call(Ref, impl_get_parent, []).

set_parent(Ref, Scheme, Term) ->
    occi_object:call(Ref, impl_set_parent, [Scheme, Term]).

get_actions(Ref) ->
    occi_object:call(Ref, impl_get_actions, []).

add_action(Ref, Action) ->
    occi_object:call(Ref, impl_add_action, [Action]).

%%
%% implementations
%%
impl_get_class(Data) ->
    {{ok, kind}, Data}.

impl_get_parent(#data{parent=Parent}=Data) ->
    {{ok, Parent}, Data}.

impl_set_parent(#data{}=Data, undefined, _Term) ->
    {{error, {einval, "Undefined scheme"}}, Data};
impl_set_parent(#data{}=Data, _Scheme, undefined) ->
    {{error, {einval, "Undefined term"}}, Data};
impl_set_parent(#data{}=Data, Scheme, Term) ->
    {ok, Data#data{parent=#occi_cid{scheme=Scheme, term=Term}}}.

impl_get_actions(#data{actions=Actions}=Data) ->
    {{ok, Actions}, Data}.

impl_add_action(#data{actions=Actions}=Data, Action) ->
    {ok, Data#data{actions=[Action|Actions]}}.
