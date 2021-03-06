-module(lager_gelf_formatter).

-include_lib("lager/include/lager.hrl").

-export([format/2, format/3]).

-spec format(lager_msg:lager_msg(),list()) -> any().
format(Msg,[]) ->
    MetaData = lager_msg:metadata(Msg),
    Keys = proplists:get_keys(MetaData),
    format(Msg, lists:append([version, host, message, timestamp, level], Keys));
format(Message,[{metadata, AdditionalMetaData} | Rest]) ->
    Destinations = lager_msg:destinations(Message),
    Metadata = lists:append(lager_msg:metadata(Message), AdditionalMetaData),
    Severity = lager_msg:severity(Message),
    Timestamp = lager_msg:timestamp(Message),
    Content = lager_msg:message(Message),
    NewMessage = lager_msg:new(Content, Timestamp, Severity, Metadata, Destinations),
    format(NewMessage, Rest);
format(Message,Config) ->
    lists:flatten([${, string:join([output(V,Message) || V <- Config], ", "), $}]).

-spec format(lager_msg:lager_msg(),list(), list()) -> any().
format(Msg, Config, _Color) ->
    format(Msg, Config).

-spec output(term(),lager_msg:lager_msg()) -> iolist().
output(message,Msg) -> [$", "short_message", $", $:, $", re:replace(lager_msg:message(Msg), "\"", "\\\\\\\"", [global, {return, list}]), $"];
output(version,_Msg) -> [$", "version", $", $:, $", "1.1", $"];
output(host,_Msg) ->
    {ok, Host} = inet:gethostname(),
    property("host", Host);
output(timestamp,Msg) ->
    {D, T} = lager_msg:datetime(Msg),
    property("timestamp",[D, "T", T]);
output(level,Msg) ->
    property("level", integer_to_list(lager_msg:severity_as_int(Msg)));
output(Prop,Msg) when is_atom(Prop) ->
    Metadata = lager_msg:metadata(Msg),
    Key = make_printable(Prop),
    RawValue = get_metadata(Prop,Metadata,"Undefined"),
    if
        % NOTE:
        % nestded structures are not supported for now
        % they are represented as strings
        %is_map(RawValue) ->
            %convert_map(make_printable(Key), RawValue);
        is_map(RawValue) ->
            property(Key, io_lib:format("~p", [RawValue]));
        true ->
            Value = make_printable(get_metadata(Prop,Metadata,"Undefined")),
            property(Key, Value)    
    end;
output({Prop,Default},Msg) when is_atom(Prop) ->
    Metadata = lager_msg:metadata(Msg),
    Key = make_printable(Prop),
    Value = make_printable(get_metadata(Prop,Metadata,output(Default,Msg))),
    property(Key, Value);
output(Other,_) -> make_printable(Other).

%% converts and formats a map into a list with keys and values, prefixes keys with name of original key
%-spec convert_map(term(), map()) -> iolist().
%convert_map(Key, M) ->
    %Fun = fun(K, V, Acc) ->
        %PrefixedKey = [Key, $_, make_printable(K)],
        %if
            %is_map(V) ->
                %E = convert_map(PrefixedKey, V);
            %true ->
                %E = [property(PrefixedKey, make_printable(V))]
        %end,
        %join_lists(E, Acc)
    %end,
    %maps:fold(Fun, [], M).

%join_lists(L, []) -> L;
%join_lists(L, A) -> [L, $, , A].

%% create string '"key": "value"' from key and value
-spec property(string(), string()) -> string().
property(Key, Value) ->
    EscapedValue = re:replace(Value, "\"", "\\\\\\\"", [global, {return, list}]),
    [$" , Key , $" , $: , $" , EscapedValue , $"].

-spec make_printable(any()) -> iolist().
make_printable(A) when is_atom(A) -> atom_to_list(A);
make_printable(P) when is_pid(P) -> pid_to_list(P);
make_printable(L) when is_list(L) -> L;
make_printable(L) when is_binary(L) -> binary_to_list(L);
make_printable(Other) -> io_lib:format("~p",[Other]).

get_metadata(Key, Metadata, Default) ->
    case lists:keyfind(Key, 1, Metadata) of
        false ->
            Default;
        {Key, Value} ->
            Value
    end.
