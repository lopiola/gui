#!/usr/bin/env escript
%% -*- erlang -*-

%%%-------------------------------------------------------------------
%%% @author Lukasz Opiola
%%% @copyright (C) 2015 ACK CYFRONET AGH
%%% This software is released under the MIT license
%%% cited in 'LICENSE.txt'.
%%% @end
%%%-------------------------------------------------------------------
%%% @doc
%%% This escript compiles the GUI files (coffee scripts and templates)
%%% and places them in release package, along with other static GUI files.
%%% It is run automatically if the project containing ctool has a config
%%% file placed exacly in rel/gui.config.
%%% @end
%%%-------------------------------------------------------------------

%% NOTE: This script is run from ctool root. Considering this,
%% the including project's root is in '../../'.
-define(INCLUDER_ROOT, "../../").

%% Resolves target release directory based on rebar.config and reltool.config.
-define(TARGET_RELEASE_LOCATION,
    begin
        {ok, _RebarConfig} = file:consult(filename:join([?INCLUDER_ROOT, "rebar.config"])),
        [_RelDir] = proplists:get_value(sub_dirs, _RebarConfig),
        {ok, _ReltoolConfig} = file:consult(filename:join([?INCLUDER_ROOT, _RelDir, "reltool.config"])),
        _ReleaseName = proplists:get_value(target_dir, _ReltoolConfig),
        filename:join([?INCLUDER_ROOT, _RelDir, _ReleaseName])
    end).

%% Predefined file with config used by this escript (location relative to including project root).
-define(GUI_CONFIG_LOCATION, "rel/gui.config").

%% Success return code
-define(SUCCESS_CODE, 0).

%% Failure return code
-define(FAILURE_CODE, 1).

%% API
-export([main/1]).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Script entry function.
%% @end
%%--------------------------------------------------------------------
-spec main(Args :: [string()]) -> no_return().
main([]) ->
    try
        ResCode = case filelib:is_file(filename:join(
            [?INCLUDER_ROOT, ?GUI_CONFIG_LOCATION])) of
                      true ->
                          print_info(
                              "Detected `gui.config` file, setting up files."),
                          _ResCode = compile_and_generate();
                      false ->
                          ?SUCCESS_CODE
                  end,
        halt(ResCode)
    catch T:M ->
        print_info("ERROR - ~p:~p~n~p",
            [T, M, erlang:get_stacktrace()]),
        halt(?FAILURE_CODE)
    end.


%%--------------------------------------------------------------------
%% @doc
%% @private
%% Performs compilation of coffee scripts and erlyDTL templates and
%% places all the static files in proper dirs in release package.
%% @end
%%--------------------------------------------------------------------
-spec compile_and_generate() -> integer().
compile_and_generate() ->
    RelDirPath = ?TARGET_RELEASE_LOCATION,
    GuiConfigPath = filename:join([?INCLUDER_ROOT, ?GUI_CONFIG_LOCATION]),
    {ok, GuiConfig} = file:consult(GuiConfigPath),
    RelaseStaticFilesDir = filename:join([RelDirPath, proplists:get_value(release_static_files_dir, GuiConfig)]),
    SourceCommonFilesDir = filename:join([?INCLUDER_ROOT, proplists:get_value(source_common_files_dir, GuiConfig)]),
    SourcePagesDir = filename:join([?INCLUDER_ROOT, proplists:get_value(source_pages_dir, GuiConfig)]),

    % Remove old files
    [] = shell_cmd(["rm", "-rf", RelaseStaticFilesDir]),
    % Create needed dirs
    [] = shell_cmd(["mkdir", "-p", RelaseStaticFilesDir]),
    % Copy all common static files
    [] = shell_cmd(["cp", "-R", SourceCommonFilesDir, RelaseStaticFilesDir]),
    % Copy all pages dirs
    [] = shell_cmd(["cp", "-R", filename:join(SourcePagesDir, "*"), RelaseStaticFilesDir]),
    % Compile .coffee files
    [] = shell_cmd(["find", RelaseStaticFilesDir, "-name", "'*.coffee'", "-exec", "coffee", "-c", "{}", "\\;"]),
    % Remove .erl and .coffee files from release location
    [] = shell_cmd(["find", RelaseStaticFilesDir, "-name", "'*.erl'", "-delete"]),
    [] = shell_cmd(["find", RelaseStaticFilesDir, "-name", "'*.coffee'", "-delete"]),
    % Move .html files to the static files root
    [] = shell_cmd(["find", RelaseStaticFilesDir, "-name", "'*.html'", "-exec", "mv", "{}", RelaseStaticFilesDir, "\\;"]),
    % Find all empty dirs and delete them
    [] = shell_cmd(["find", RelaseStaticFilesDir, "-empty", "-type", "d", "-delete"]),
    % Finally, log success.
    print_info("Successfully processed GUI files."),
    ?SUCCESS_CODE.


%%--------------------------------------------------------------------
%% @doc
%% @private
%% Performs a shell call given a list of arguments.
%% @end
%%--------------------------------------------------------------------
-spec shell_cmd([string()]) -> string().
shell_cmd(List) ->
    os:cmd(string:join(List, " ")).


print_info(Format) ->
    print_info(Format, []).

print_info(Format, Args) ->
    io:format("[GUI COMPILER] " ++ Format ++ "~n", Args).