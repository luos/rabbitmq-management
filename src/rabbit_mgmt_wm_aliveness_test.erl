%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%
%% Copyright (c) 2007-2020 VMware, Inc. or its affiliates.  All rights reserved.
%%

-module(rabbit_mgmt_wm_aliveness_test).

-export([init/2, to_json/2, content_types_provided/2, is_authorized/2]).
-export([resource_exists/2]).
-export([variances/2]).

-include_lib("rabbitmq_management_agent/include/rabbit_mgmt_records.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").

-define(QUEUE, <<"aliveness-test">>).

%%--------------------------------------------------------------------

init(Req, _State) ->
    {cowboy_rest, rabbit_mgmt_headers:set_common_permission_headers(Req, ?MODULE), #context{}}.

variances(Req, Context) ->
    {[<<"accept-encoding">>, <<"origin">>], Req, Context}.

content_types_provided(ReqData, Context) ->
   {rabbit_mgmt_util:responder_map(to_json), ReqData, Context}.

resource_exists(ReqData, Context) ->
    {case rabbit_mgmt_util:vhost(ReqData) of
         not_found -> false;
         _         -> true
     end, ReqData, Context}.

to_json(ReqData, Context) ->
    rabbit_mgmt_util:with_channel(
      rabbit_mgmt_util:vhost(ReqData), ReqData, Context,
      fun(Ch) ->
              amqp_channel:call(Ch, #'queue.declare'{queue = ?QUEUE}),
              amqp_channel:call(Ch, #'basic.publish'{routing_key = ?QUEUE},
                                #amqp_msg{payload = <<"test_message">>}),
              {#'basic.get_ok'{}, _} =
                  amqp_channel:call(Ch, #'basic.get'{queue  = ?QUEUE,
                                                     no_ack = true}),
              %% Don't delete the queue. If this is pinged every few
              %% seconds we don't want to create a mnesia transaction
              %% each time.
              rabbit_mgmt_util:reply([{status, ok}], ReqData, Context)
      end).

is_authorized(ReqData, Context) ->
    rabbit_mgmt_util:is_authorized_vhost(ReqData, Context).

