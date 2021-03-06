%%% @author Jean Parpaillon <jean.parpaillon@free.fr>
%%% @copyright (C) 2014, Jean Parpaillon
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
%%% Created : 5 Mar 2014 by Jean Parpaillon <jean.parpaillon@free.fr>
%%%-------------------------------------------------------------------
-module(occi_parser_occi).
-compile({parse_transform, lager_transform}).

-include("occi_parser_text.hrl").

%% API
-export([parse_action/3,
	 parse_entity/3,
	 parse_user_mixin/2,
	 parse_collection/2]).

%%%===================================================================
%%% API
%%%===================================================================
parse_action(_, Req, Action) ->
    case parse_headers(Req, orddict:new()) of
	{error, Err} ->
	    {error, Err};
	{ok, Headers} ->
	    occi_parser_text:parse_action(Headers, #state{action=Action})
    end.    

parse_entity(_, Req, #occi_resource{}=Res) ->
    case parse_headers(Req, orddict:new()) of
	{error, Err} ->
	    {error, Err};
	{ok, Headers} ->
	    occi_parser_text:parse_entity(Headers, #state{entity=Res})
    end;

parse_entity(_, Req, #occi_link{}=Link) ->
    case parse_headers(Req, orddict:new()) of
	{error, Err} ->
	    {error, Err};
	{ok, Headers} ->
	    occi_parser_text:parse_entity(Headers, #state{entity=Link})
    end;

parse_entity(_, Req, #occi_entity{id=Id}) ->
    case parse_headers(Req, orddict:new()) of
	{error, Err} ->
	    {error, Err};
	{ok, Headers} ->
	    occi_parser_text:parse_entity(Headers, #state{entity_id=Id})
    end.

parse_user_mixin(_, Req) ->
    case parse_headers(Req, orddict:new()) of
	{error, Err} ->
	    {error, Err};
	{ok, Headers} ->
	    occi_parser_text:parse_user_mixin(Headers, #state{mixin=occi_mixin:new(#occi_cid{class=usermixin})})
    end.

parse_collection(_, Req) ->
    case parse_headers(Req, orddict:new()) of
	{error, Err} ->
	    {error, Err};
	{ok, Headers} ->
	    occi_parser_text:parse_collection(Headers, #state{})
    end.

%%%
%%% Priv
%%%
parse_headers(Req, Acc) ->
    {Headers, _} = cowboy_req:headers(Req),
    H = parse_header(Headers, Acc),
    lager:debug("### headers: ~p~n", [H]),
    H.

parse_header([], Acc) ->
    {ok, reverse(Acc)};
parse_header([{Name, Bin}|T], Acc) ->
    parse_header(T, add_header_value(Name, parse_values(Bin), Acc)).

parse_values(Bin) ->
    parse_values(Bin, <<>>, []).

parse_values(<<>>, SoFar, Acc) ->
    [SoFar | Acc];
parse_values(<< $\\, $,, Rest/bits >>, SoFar, Acc) ->
    parse_values(Rest, << SoFar/binary, $,, $\\ >>, Acc);
parse_values(<< $,, Rest/bits >>, <<>>, Acc) ->
    parse_values(Rest, <<>>, Acc);
parse_values(<< $,, Rest/bits >>, SoFar, Acc) ->
    parse_values(Rest, <<>>, [SoFar | Acc]);
parse_values(<< C, Rest/bits >>, SoFar, Acc) ->
    parse_values(Rest, << SoFar/binary, C >>, Acc).

add_header_value(Name, V, Acc) when is_binary(Name) ->
    add_header_value(list_to_atom(binary_to_list(Name)), V, Acc);
add_header_value(Name, Values, Acc) ->
    case orddict:find(Name, Acc) of
	{ok, V} -> 
	    orddict:store(Name, Values ++ V, Acc);
	error -> 
	    orddict:store(Name, Values, Acc)
    end.

reverse(H) ->
    orddict:fold(fun (Key, Values, Acc) ->
			 orddict:store(Key, lists:reverse(Values), Acc)
		 end, orddict:new(), H).
