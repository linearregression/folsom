%%%
%%% Copyright 2011, fast_ip
%%%
%%% Licensed under the Apache License, Version 2.0 (the "License");
%%% you may not use this file except in compliance with the License.
%%% You may obtain a copy of the License at
%%%
%%%     http://www.apache.org/licenses/LICENSE-2.0
%%%
%%% Unless required by applicable law or agreed to in writing, software
%%% distributed under the License is distributed on an "AS IS" BASIS,
%%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%% See the License for the specific language governing permissions and
%%% limitations under the License.
%%%


%%%-------------------------------------------------------------------
%%% File:      folsom_metrics_resource.erl
%%% @author    joe williams <j@fastip.com>
%%% @copyright 2011 fast_ip
%%% @doc
%%% http end point that produces metrics collected from event handlers
%%% @end
%%%------------------------------------------------------------------

-module(folsom_events_resource).

-export([init/1,
         content_types_provided/2,
         content_types_accepted/2,
         to_json/2,
         from_json/2,
         allowed_methods/2,
         resource_exists/2,
         delete_resource/2]).

-include("folsom.hrl").
-include_lib("webmachine/include/webmachine.hrl").

init(_) -> {ok, undefined}.

content_types_provided(ReqData, Context) ->
    {[{"application/json", to_json}], ReqData, Context}.

content_types_accepted(ReqData, Context) ->
    {[{"application/json", from_json}], ReqData, Context}.

allowed_methods(ReqData, Context) ->
    {['GET', 'PUT', 'DELETE'], ReqData, Context}.

resource_exists(ReqData, Context) ->
    resource_exists(wrq:path_info(id, ReqData), ReqData, Context).

delete_resource(ReqData, Context) ->
    Id = wrq:path_info(id, ReqData),
    folsom_events_event:delete_handler(list_to_atom(Id)),
    {true, ReqData, Context}.

to_json(ReqData, Context) ->
    Id = wrq:path_info(id, ReqData),
    Limit = wrq:get_qs_value("limit", integer_to_list(?DEFAULT_LIMIT), ReqData),
    Tag = wrq:get_qs_value("tag", "undefined", ReqData),
    Info = wrq:get_qs_value("info", "undefined", ReqData),
    Result = get_request(Id, list_to_integer(Limit), list_to_atom(Tag), list_to_atom(Info)),
    {mochijson2:encode(Result), ReqData, Context}.

from_json(ReqData, Context) ->
    {struct, Body} = mochijson2:decode(wrq:req_body(ReqData)),
    Result = put_request(wrq:path_info(id, ReqData), Body),
    {mochijson2:encode(Result), ReqData, Context}.


% internal fuctions


resource_exists(undefined, ReqData, Context) ->
    {true, ReqData, Context};
resource_exists(Id, ReqData, Context) ->
    {folsom_events_event:handler_exists(list_to_atom(Id)), ReqData, Context}.

get_request(undefined, _, undefined, undefined) ->
    folsom_events_event:get_handlers();
get_request(undefined, _, undefined, true) ->
    folsom_events_event:get_handlers_info();
get_request(undefined, _, Tag, undefined) ->
    folsom_events_event:get_tagged_handlers(Tag);
get_request(Id, Limit, undefined, undefined) ->
    folsom_events_event:get_events(list_to_atom(Id), Limit);
get_request(Id, Limit, Tag, undefined) ->
    folsom_events_event:get_events(list_to_atom(Id), Tag, Limit).

put_request(undefined, Body) ->
    Id = folsom_utils:to_atom(proplists:get_value(<<"id">>, Body)),
    Tags = proplists:get_value(<<"tags">>, Body, []),
    AtomTags = folsom_utils:convert_tags(Tags),
    Size = proplists:get_value(<<"size">>, Body, ?DEFAULT_SIZE),
    add_handler(Id, AtomTags, Size);
put_request(Id, Body) ->
    Event = proplists:get_value(<<"event">>, Body),
    Tags = proplists:get_value(<<"tags">>, Body, []),
    AtomTags = folsom_utils:convert_tags(Tags),
    folsom_events_event:notify({list_to_atom(Id), AtomTags, Event}).

add_handler(Id, Tags, Size) ->
    folsom_events_event:add_handler(Id, Tags, Size).


