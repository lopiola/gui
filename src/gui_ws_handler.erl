-module(gui_ws_handler).

-include_lib("ctool/include/logging.hrl").

-export([init/3]).
-export([websocket_init/3]).
-export([websocket_handle/3]).
-export([websocket_info/3]).
-export([websocket_terminate/3]).


-define(PULL_RESP, "pullResp").

init({_, http}, _Req, _Opts) ->
    {upgrade, protocol, cowboy_websocket}.

websocket_init(_TransportName, Req, _Opts) ->
%%     erlang:start_timer(1000, opn_cowboy_bridge:get_socket_pid(), roz),
    case gui_html_handler:is_html_req(Req) of
        true ->
            % Initialize context
            g_ctx:init(Req),
            (g_ctx:page_module()):websocket_init();
        false ->
            % Skip
            ok
    end,
    {ok, Req, undefined_state}.

websocket_handle({text, MsgJSON}, Req, State) ->
    Msg = g_str:decode_from_json(MsgJSON),
    ?dump(Msg),
    Resp = gui_html_handler:handle_ws_req(Msg),
    ?dump(Resp),
    RespJSON = g_str:encode_to_json(Resp),
    {reply, {text, RespJSON}, Req, State};
websocket_handle(_Data, Req, State) ->
    {ok, Req, State}.

websocket_info({timeout, _Ref, roz}, Req, State) ->
    Roz = [
        {<<"msgType">>, <<"pushReq">>},
        {<<"data">>, [
            {<<"id">>, <<"t3">>}, {<<"title">>, <<"HiehieHie">>}, {<<"isCompleted">>, true}
        ]}
    ],
    {reply, {text, g_str:encode_to_json(Roz)}, Req, State};

websocket_info({timeout, _Ref, Msg}, Req, State) ->
%%     erlang:start_timer(1000, opn_cowboy_bridge:get_socket_pid(), <<"How' you doin'?">>),
    {reply, {text, Msg}, Req, State};
websocket_info(_Info, Req, State) ->
    {ok, Req, State}.

websocket_terminate(_Reason, _Req, _State) ->
    ok.
