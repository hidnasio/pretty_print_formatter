-file("/usr/local/Cellar/erlang/20.3.4/lib/erlang/lib/parsetools-2.1.6/include/leexinc.hrl", 0).
%% The source of this file is part of leex distribution, as such it
%% has the same Copyright as the other files in the leex
%% distribution. The Copyright is defined in the accompanying file
%% COPYRIGHT. However, the resultant scanner generated by leex is the
%% property of the creator of the scanner and is not covered by that
%% Copyright.

-module(sql_lexer).

-export([string/1,string/2,token/2,token/3,tokens/2,tokens/3]).
-export([format_error/1]).

%% User code. This is placed here to allow extra attributes.
-file("src/sql_lexer.xrl", 26).

-file("/usr/local/Cellar/erlang/20.3.4/lib/erlang/lib/parsetools-2.1.6/include/leexinc.hrl", 14).

format_error({illegal,S}) -> ["illegal characters ",io_lib:write_string(S)];
format_error({user,S}) -> S.

string(String) -> string(String, 1).

string(String, Line) -> string(String, Line, String, []).

%% string(InChars, Line, TokenChars, Tokens) ->
%% {ok,Tokens,Line} | {error,ErrorInfo,Line}.
%% Note the line number going into yystate, L0, is line of token
%% start while line number returned is line of token end. We want line
%% of token start.

string([], L, [], Ts) ->                     % No partial tokens!
    {ok,yyrev(Ts),L};
string(Ics0, L0, Tcs, Ts) ->
    case yystate(yystate(), Ics0, L0, 0, reject, 0) of
        {A,Alen,Ics1,L1} ->                  % Accepting end state
            string_cont(Ics1, L1, yyaction(A, Alen, Tcs, L0), Ts);
        {A,Alen,Ics1,L1,_S1} ->              % Accepting transistion state
            string_cont(Ics1, L1, yyaction(A, Alen, Tcs, L0), Ts);
        {reject,_Alen,Tlen,_Ics1,L1,_S1} ->  % After a non-accepting state
            {error,{L0,?MODULE,{illegal,yypre(Tcs, Tlen+1)}},L1};
        {A,Alen,Tlen,_Ics1,L1,_S1} ->
            Tcs1 = yysuf(Tcs, Alen),
            L2 = adjust_line(Tlen, Alen, Tcs1, L1),
            string_cont(Tcs1, L2, yyaction(A, Alen, Tcs, L0), Ts)
    end.

%% string_cont(RestChars, Line, Token, Tokens)
%% Test for and remove the end token wrapper. Push back characters
%% are prepended to RestChars.

-dialyzer({nowarn_function, string_cont/4}).

string_cont(Rest, Line, {token,T}, Ts) ->
    string(Rest, Line, Rest, [T|Ts]);
string_cont(Rest, Line, {token,T,Push}, Ts) ->
    NewRest = Push ++ Rest,
    string(NewRest, Line, NewRest, [T|Ts]);
string_cont(Rest, Line, {end_token,T}, Ts) ->
    string(Rest, Line, Rest, [T|Ts]);
string_cont(Rest, Line, {end_token,T,Push}, Ts) ->
    NewRest = Push ++ Rest,
    string(NewRest, Line, NewRest, [T|Ts]);
string_cont(Rest, Line, skip_token, Ts) ->
    string(Rest, Line, Rest, Ts);
string_cont(Rest, Line, {skip_token,Push}, Ts) ->
    NewRest = Push ++ Rest,
    string(NewRest, Line, NewRest, Ts);
string_cont(_Rest, Line, {error,S}, _Ts) ->
    {error,{Line,?MODULE,{user,S}},Line}.

%% token(Continuation, Chars) ->
%% token(Continuation, Chars, Line) ->
%% {more,Continuation} | {done,ReturnVal,RestChars}.
%% Must be careful when re-entering to append the latest characters to the
%% after characters in an accept. The continuation is:
%% {token,State,CurrLine,TokenChars,TokenLen,TokenLine,AccAction,AccLen}

token(Cont, Chars) -> token(Cont, Chars, 1).

token([], Chars, Line) ->
    token(yystate(), Chars, Line, Chars, 0, Line, reject, 0);
token({token,State,Line,Tcs,Tlen,Tline,Action,Alen}, Chars, _) ->
    token(State, Chars, Line, Tcs ++ Chars, Tlen, Tline, Action, Alen).

%% token(State, InChars, Line, TokenChars, TokenLen, TokenLine,
%% AcceptAction, AcceptLen) ->
%% {more,Continuation} | {done,ReturnVal,RestChars}.
%% The argument order is chosen to be more efficient.

token(S0, Ics0, L0, Tcs, Tlen0, Tline, A0, Alen0) ->
    case yystate(S0, Ics0, L0, Tlen0, A0, Alen0) of
        %% Accepting end state, we have a token.
        {A1,Alen1,Ics1,L1} ->
            token_cont(Ics1, L1, yyaction(A1, Alen1, Tcs, Tline));
        %% Accepting transition state, can take more chars.
        {A1,Alen1,[],L1,S1} ->                  % Need more chars to check
            {more,{token,S1,L1,Tcs,Alen1,Tline,A1,Alen1}};
        {A1,Alen1,Ics1,L1,_S1} ->               % Take what we got
            token_cont(Ics1, L1, yyaction(A1, Alen1, Tcs, Tline));
        %% After a non-accepting state, maybe reach accept state later.
        {A1,Alen1,Tlen1,[],L1,S1} ->            % Need more chars to check
            {more,{token,S1,L1,Tcs,Tlen1,Tline,A1,Alen1}};
        {reject,_Alen1,Tlen1,eof,L1,_S1} ->     % No token match
            %% Check for partial token which is error.
            Ret = if Tlen1 > 0 -> {error,{Tline,?MODULE,
                                          %% Skip eof tail in Tcs.
                                          {illegal,yypre(Tcs, Tlen1)}},L1};
                     true -> {eof,L1}
                  end,
            {done,Ret,eof};
        {reject,_Alen1,Tlen1,Ics1,L1,_S1} ->    % No token match
            Error = {Tline,?MODULE,{illegal,yypre(Tcs, Tlen1+1)}},
            {done,{error,Error,L1},Ics1};
        {A1,Alen1,Tlen1,_Ics1,L1,_S1} ->       % Use last accept match
            Tcs1 = yysuf(Tcs, Alen1),
            L2 = adjust_line(Tlen1, Alen1, Tcs1, L1),
            token_cont(Tcs1, L2, yyaction(A1, Alen1, Tcs, Tline))
    end.

%% token_cont(RestChars, Line, Token)
%% If we have a token or error then return done, else if we have a
%% skip_token then continue.

-dialyzer({nowarn_function, token_cont/3}).

token_cont(Rest, Line, {token,T}) ->
    {done,{ok,T,Line},Rest};
token_cont(Rest, Line, {token,T,Push}) ->
    NewRest = Push ++ Rest,
    {done,{ok,T,Line},NewRest};
token_cont(Rest, Line, {end_token,T}) ->
    {done,{ok,T,Line},Rest};
token_cont(Rest, Line, {end_token,T,Push}) ->
    NewRest = Push ++ Rest,
    {done,{ok,T,Line},NewRest};
token_cont(Rest, Line, skip_token) ->
    token(yystate(), Rest, Line, Rest, 0, Line, reject, 0);
token_cont(Rest, Line, {skip_token,Push}) ->
    NewRest = Push ++ Rest,
    token(yystate(), NewRest, Line, NewRest, 0, Line, reject, 0);
token_cont(Rest, Line, {error,S}) ->
    {done,{error,{Line,?MODULE,{user,S}},Line},Rest}.

%% tokens(Continuation, Chars, Line) ->
%% {more,Continuation} | {done,ReturnVal,RestChars}.
%% Must be careful when re-entering to append the latest characters to the
%% after characters in an accept. The continuation is:
%% {tokens,State,CurrLine,TokenChars,TokenLen,TokenLine,Tokens,AccAction,AccLen}
%% {skip_tokens,State,CurrLine,TokenChars,TokenLen,TokenLine,Error,AccAction,AccLen}

tokens(Cont, Chars) -> tokens(Cont, Chars, 1).

tokens([], Chars, Line) ->
    tokens(yystate(), Chars, Line, Chars, 0, Line, [], reject, 0);
tokens({tokens,State,Line,Tcs,Tlen,Tline,Ts,Action,Alen}, Chars, _) ->
    tokens(State, Chars, Line, Tcs ++ Chars, Tlen, Tline, Ts, Action, Alen);
tokens({skip_tokens,State,Line,Tcs,Tlen,Tline,Error,Action,Alen}, Chars, _) ->
    skip_tokens(State, Chars, Line, Tcs ++ Chars, Tlen, Tline, Error, Action, Alen).

%% tokens(State, InChars, Line, TokenChars, TokenLen, TokenLine, Tokens,
%% AcceptAction, AcceptLen) ->
%% {more,Continuation} | {done,ReturnVal,RestChars}.

tokens(S0, Ics0, L0, Tcs, Tlen0, Tline, Ts, A0, Alen0) ->
    case yystate(S0, Ics0, L0, Tlen0, A0, Alen0) of
        %% Accepting end state, we have a token.
        {A1,Alen1,Ics1,L1} ->
            tokens_cont(Ics1, L1, yyaction(A1, Alen1, Tcs, Tline), Ts);
        %% Accepting transition state, can take more chars.
        {A1,Alen1,[],L1,S1} ->                  % Need more chars to check
            {more,{tokens,S1,L1,Tcs,Alen1,Tline,Ts,A1,Alen1}};
        {A1,Alen1,Ics1,L1,_S1} ->               % Take what we got
            tokens_cont(Ics1, L1, yyaction(A1, Alen1, Tcs, Tline), Ts);
        %% After a non-accepting state, maybe reach accept state later.
        {A1,Alen1,Tlen1,[],L1,S1} ->            % Need more chars to check
            {more,{tokens,S1,L1,Tcs,Tlen1,Tline,Ts,A1,Alen1}};
        {reject,_Alen1,Tlen1,eof,L1,_S1} ->     % No token match
            %% Check for partial token which is error, no need to skip here.
            Ret = if Tlen1 > 0 -> {error,{Tline,?MODULE,
                                          %% Skip eof tail in Tcs.
                                          {illegal,yypre(Tcs, Tlen1)}},L1};
                     Ts == [] -> {eof,L1};
                     true -> {ok,yyrev(Ts),L1}
                  end,
            {done,Ret,eof};
        {reject,_Alen1,Tlen1,_Ics1,L1,_S1} ->
            %% Skip rest of tokens.
            Error = {L1,?MODULE,{illegal,yypre(Tcs, Tlen1+1)}},
            skip_tokens(yysuf(Tcs, Tlen1+1), L1, Error);
        {A1,Alen1,Tlen1,_Ics1,L1,_S1} ->
            Token = yyaction(A1, Alen1, Tcs, Tline),
            Tcs1 = yysuf(Tcs, Alen1),
            L2 = adjust_line(Tlen1, Alen1, Tcs1, L1),
            tokens_cont(Tcs1, L2, Token, Ts)
    end.

%% tokens_cont(RestChars, Line, Token, Tokens)
%% If we have an end_token or error then return done, else if we have
%% a token then save it and continue, else if we have a skip_token
%% just continue.

-dialyzer({nowarn_function, tokens_cont/4}).

tokens_cont(Rest, Line, {token,T}, Ts) ->
    tokens(yystate(), Rest, Line, Rest, 0, Line, [T|Ts], reject, 0);
tokens_cont(Rest, Line, {token,T,Push}, Ts) ->
    NewRest = Push ++ Rest,
    tokens(yystate(), NewRest, Line, NewRest, 0, Line, [T|Ts], reject, 0);
tokens_cont(Rest, Line, {end_token,T}, Ts) ->
    {done,{ok,yyrev(Ts, [T]),Line},Rest};
tokens_cont(Rest, Line, {end_token,T,Push}, Ts) ->
    NewRest = Push ++ Rest,
    {done,{ok,yyrev(Ts, [T]),Line},NewRest};
tokens_cont(Rest, Line, skip_token, Ts) ->
    tokens(yystate(), Rest, Line, Rest, 0, Line, Ts, reject, 0);
tokens_cont(Rest, Line, {skip_token,Push}, Ts) ->
    NewRest = Push ++ Rest,
    tokens(yystate(), NewRest, Line, NewRest, 0, Line, Ts, reject, 0);
tokens_cont(Rest, Line, {error,S}, _Ts) ->
    skip_tokens(Rest, Line, {Line,?MODULE,{user,S}}).

%%skip_tokens(InChars, Line, Error) -> {done,{error,Error,Line},Ics}.
%% Skip tokens until an end token, junk everything and return the error.

skip_tokens(Ics, Line, Error) ->
    skip_tokens(yystate(), Ics, Line, Ics, 0, Line, Error, reject, 0).

%% skip_tokens(State, InChars, Line, TokenChars, TokenLen, TokenLine, Tokens,
%% AcceptAction, AcceptLen) ->
%% {more,Continuation} | {done,ReturnVal,RestChars}.

skip_tokens(S0, Ics0, L0, Tcs, Tlen0, Tline, Error, A0, Alen0) ->
    case yystate(S0, Ics0, L0, Tlen0, A0, Alen0) of
        {A1,Alen1,Ics1,L1} ->                  % Accepting end state
            skip_cont(Ics1, L1, yyaction(A1, Alen1, Tcs, Tline), Error);
        {A1,Alen1,[],L1,S1} ->                 % After an accepting state
            {more,{skip_tokens,S1,L1,Tcs,Alen1,Tline,Error,A1,Alen1}};
        {A1,Alen1,Ics1,L1,_S1} ->
            skip_cont(Ics1, L1, yyaction(A1, Alen1, Tcs, Tline), Error);
        {A1,Alen1,Tlen1,[],L1,S1} ->           % After a non-accepting state
            {more,{skip_tokens,S1,L1,Tcs,Tlen1,Tline,Error,A1,Alen1}};
        {reject,_Alen1,_Tlen1,eof,L1,_S1} ->
            {done,{error,Error,L1},eof};
        {reject,_Alen1,Tlen1,_Ics1,L1,_S1} ->
            skip_tokens(yysuf(Tcs, Tlen1+1), L1, Error);
        {A1,Alen1,Tlen1,_Ics1,L1,_S1} ->
            Token = yyaction(A1, Alen1, Tcs, Tline),
            Tcs1 = yysuf(Tcs, Alen1),
            L2 = adjust_line(Tlen1, Alen1, Tcs1, L1),
            skip_cont(Tcs1, L2, Token, Error)
    end.

%% skip_cont(RestChars, Line, Token, Error)
%% Skip tokens until we have an end_token or error then return done
%% with the original rror.

-dialyzer({nowarn_function, skip_cont/4}).

skip_cont(Rest, Line, {token,_T}, Error) ->
    skip_tokens(yystate(), Rest, Line, Rest, 0, Line, Error, reject, 0);
skip_cont(Rest, Line, {token,_T,Push}, Error) ->
    NewRest = Push ++ Rest,
    skip_tokens(yystate(), NewRest, Line, NewRest, 0, Line, Error, reject, 0);
skip_cont(Rest, Line, {end_token,_T}, Error) ->
    {done,{error,Error,Line},Rest};
skip_cont(Rest, Line, {end_token,_T,Push}, Error) ->
    NewRest = Push ++ Rest,
    {done,{error,Error,Line},NewRest};
skip_cont(Rest, Line, skip_token, Error) ->
    skip_tokens(yystate(), Rest, Line, Rest, 0, Line, Error, reject, 0);
skip_cont(Rest, Line, {skip_token,Push}, Error) ->
    NewRest = Push ++ Rest,
    skip_tokens(yystate(), NewRest, Line, NewRest, 0, Line, Error, reject, 0);
skip_cont(Rest, Line, {error,_S}, Error) ->
    skip_tokens(yystate(), Rest, Line, Rest, 0, Line, Error, reject, 0).

-compile({nowarn_unused_function, [yyrev/1, yyrev/2, yypre/2, yysuf/2]}).

yyrev(List) -> lists:reverse(List).
yyrev(List, Tail) -> lists:reverse(List, Tail).
yypre(List, N) -> lists:sublist(List, N).
yysuf(List, N) -> lists:nthtail(N, List).

%% adjust_line(TokenLength, AcceptLength, Chars, Line) -> NewLine
%% Make sure that newlines in Chars are not counted twice.
%% Line has been updated with respect to newlines in the prefix of
%% Chars consisting of (TokenLength - AcceptLength) characters.

-compile({nowarn_unused_function, adjust_line/4}).

adjust_line(N, N, _Cs, L) -> L;
adjust_line(T, A, [$\n|Cs], L) ->
    adjust_line(T-1, A, Cs, L-1);
adjust_line(T, A, [_|Cs], L) ->
    adjust_line(T-1, A, Cs, L).

%% yystate() -> InitialState.
%% yystate(State, InChars, Line, CurrTokLen, AcceptAction, AcceptLen) ->
%% {Action, AcceptLen, RestChars, Line} |
%% {Action, AcceptLen, RestChars, Line, State} |
%% {reject, AcceptLen, CurrTokLen, RestChars, Line, State} |
%% {Action, AcceptLen, CurrTokLen, RestChars, Line, State}.
%% Generated state transition functions. The non-accepting end state
%% return signal either an unrecognised character or end of current
%% input.

-file("src/sql_lexer.erl", 307).
yystate() -> 76.

yystate(91, [69|Ics], Line, Tlen, Action, Alen) ->
    yystate(77, Ics, Line, Tlen+1, Action, Alen);
yystate(91, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,91};
yystate(90, [78|Ics], Line, Tlen, Action, Alen) ->
    yystate(78, Ics, Line, Tlen+1, Action, Alen);
yystate(90, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,90};
yystate(89, [79|Ics], Line, Tlen, Action, Alen) ->
    yystate(81, Ics, Line, Tlen+1, Action, Alen);
yystate(89, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,89};
yystate(88, [70|Ics], Line, Tlen, Action, Alen) ->
    yystate(80, Ics, Line, Tlen+1, Action, Alen);
yystate(88, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,88};
yystate(87, [85|Ics], Line, Tlen, Action, Alen) ->
    yystate(71, Ics, Line, Tlen+1, Action, Alen);
yystate(87, [82|Ics], Line, Tlen, Action, Alen) ->
    yystate(55, Ics, Line, Tlen+1, Action, Alen);
yystate(87, [78|Ics], Line, Tlen, Action, Alen) ->
    yystate(12, Ics, Line, Tlen+1, Action, Alen);
yystate(87, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,87};
yystate(86, [69|Ics], Line, Tlen, Action, Alen) ->
    yystate(82, Ics, Line, Tlen+1, Action, Alen);
yystate(86, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,86};
yystate(85, [89|Ics], Line, Tlen, Action, Alen) ->
    yystate(12, Ics, Line, Tlen+1, Action, Alen);
yystate(85, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,85};
yystate(84, [32|Ics], Line, Tlen, _, _) ->
    yystate(84, Ics, Line, Tlen+1, 5, Tlen);
yystate(84, [13|Ics], Line, Tlen, _, _) ->
    yystate(84, Ics, Line, Tlen+1, 5, Tlen);
yystate(84, [9|Ics], Line, Tlen, _, _) ->
    yystate(84, Ics, Line, Tlen+1, 5, Tlen);
yystate(84, [10|Ics], Line, Tlen, _, _) ->
    yystate(84, Ics, Line+1, Tlen+1, 5, Tlen);
yystate(84, Ics, Line, Tlen, _, _) ->
    {5,Tlen,Ics,Line,84};
yystate(83, [83|Ics], Line, Tlen, Action, Alen) ->
    yystate(67, Ics, Line, Tlen+1, Action, Alen);
yystate(83, [78|Ics], Line, Tlen, Action, Alen) ->
    yystate(59, Ics, Line, Tlen+1, Action, Alen);
yystate(83, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,83};
yystate(82, [84|Ics], Line, Tlen, Action, Alen) ->
    yystate(70, Ics, Line, Tlen+1, Action, Alen);
yystate(82, [67|Ics], Line, Tlen, Action, Alen) ->
    yystate(17, Ics, Line, Tlen+1, Action, Alen);
yystate(82, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,82};
yystate(81, [85|Ics], Line, Tlen, Action, Alen) ->
    yystate(65, Ics, Line, Tlen+1, Action, Alen);
yystate(81, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,81};
yystate(80, [84|Ics], Line, Tlen, Action, Alen) ->
    yystate(12, Ics, Line, Tlen+1, Action, Alen);
yystate(80, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,80};
yystate(79, [82|Ics], Line, Tlen, Action, Alen) ->
    yystate(89, Ics, Line, Tlen+1, Action, Alen);
yystate(79, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,79};
yystate(78, [67|Ics], Line, Tlen, Action, Alen) ->
    yystate(80, Ics, Line, Tlen+1, Action, Alen);
yystate(78, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,78};
yystate(77, [83|Ics], Line, Tlen, Action, Alen) ->
    yystate(12, Ics, Line, Tlen+1, Action, Alen);
yystate(77, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,77};
yystate(76, [95|Ics], Line, Tlen, Action, Alen) ->
    yystate(52, Ics, Line, Tlen+1, Action, Alen);
yystate(76, [87|Ics], Line, Tlen, Action, Alen) ->
    yystate(60, Ics, Line, Tlen+1, Action, Alen);
yystate(76, [86|Ics], Line, Tlen, Action, Alen) ->
    yystate(51, Ics, Line, Tlen+1, Action, Alen);
yystate(76, [85|Ics], Line, Tlen, Action, Alen) ->
    yystate(69, Ics, Line, Tlen+1, Action, Alen);
yystate(76, [84|Ics], Line, Tlen, Action, Alen) ->
    yystate(5, Ics, Line, Tlen+1, Action, Alen);
yystate(76, [83|Ics], Line, Tlen, Action, Alen) ->
    yystate(26, Ics, Line, Tlen+1, Action, Alen);
yystate(76, [82|Ics], Line, Tlen, Action, Alen) ->
    yystate(86, Ics, Line, Tlen+1, Action, Alen);
yystate(76, [79|Ics], Line, Tlen, Action, Alen) ->
    yystate(87, Ics, Line, Tlen+1, Action, Alen);
yystate(76, [78|Ics], Line, Tlen, Action, Alen) ->
    yystate(7, Ics, Line, Tlen+1, Action, Alen);
yystate(76, [76|Ics], Line, Tlen, Action, Alen) ->
    yystate(40, Ics, Line, Tlen+1, Action, Alen);
yystate(76, [74|Ics], Line, Tlen, Action, Alen) ->
    yystate(64, Ics, Line, Tlen+1, Action, Alen);
yystate(76, [73|Ics], Line, Tlen, Action, Alen) ->
    yystate(16, Ics, Line, Tlen+1, Action, Alen);
yystate(76, [71|Ics], Line, Tlen, Action, Alen) ->
    yystate(79, Ics, Line, Tlen+1, Action, Alen);
yystate(76, [70|Ics], Line, Tlen, Action, Alen) ->
    yystate(53, Ics, Line, Tlen+1, Action, Alen);
yystate(76, [68|Ics], Line, Tlen, Action, Alen) ->
    yystate(30, Ics, Line, Tlen+1, Action, Alen);
yystate(76, [67|Ics], Line, Tlen, Action, Alen) ->
    yystate(2, Ics, Line, Tlen+1, Action, Alen);
yystate(76, [66|Ics], Line, Tlen, Action, Alen) ->
    yystate(85, Ics, Line, Tlen+1, Action, Alen);
yystate(76, [65|Ics], Line, Tlen, Action, Alen) ->
    yystate(83, Ics, Line, Tlen+1, Action, Alen);
yystate(76, [46|Ics], Line, Tlen, Action, Alen) ->
    yystate(52, Ics, Line, Tlen+1, Action, Alen);
yystate(76, [44|Ics], Line, Tlen, Action, Alen) ->
    yystate(27, Ics, Line, Tlen+1, Action, Alen);
yystate(76, [42|Ics], Line, Tlen, Action, Alen) ->
    yystate(68, Ics, Line, Tlen+1, Action, Alen);
yystate(76, [43|Ics], Line, Tlen, Action, Alen) ->
    yystate(68, Ics, Line, Tlen+1, Action, Alen);
yystate(76, [41|Ics], Line, Tlen, Action, Alen) ->
    yystate(11, Ics, Line, Tlen+1, Action, Alen);
yystate(76, [40|Ics], Line, Tlen, Action, Alen) ->
    yystate(4, Ics, Line, Tlen+1, Action, Alen);
yystate(76, [36|Ics], Line, Tlen, Action, Alen) ->
    yystate(20, Ics, Line, Tlen+1, Action, Alen);
yystate(76, [34|Ics], Line, Tlen, Action, Alen) ->
    yystate(52, Ics, Line, Tlen+1, Action, Alen);
yystate(76, [33|Ics], Line, Tlen, Action, Alen) ->
    yystate(68, Ics, Line, Tlen+1, Action, Alen);
yystate(76, [32|Ics], Line, Tlen, Action, Alen) ->
    yystate(84, Ics, Line, Tlen+1, Action, Alen);
yystate(76, [13|Ics], Line, Tlen, Action, Alen) ->
    yystate(84, Ics, Line, Tlen+1, Action, Alen);
yystate(76, [9|Ics], Line, Tlen, Action, Alen) ->
    yystate(84, Ics, Line, Tlen+1, Action, Alen);
yystate(76, [10|Ics], Line, Tlen, Action, Alen) ->
    yystate(84, Ics, Line+1, Tlen+1, Action, Alen);
yystate(76, [C|Ics], Line, Tlen, Action, Alen) when C >= 48, C =< 57 ->
    yystate(43, Ics, Line, Tlen+1, Action, Alen);
yystate(76, [C|Ics], Line, Tlen, Action, Alen) when C >= 60, C =< 62 ->
    yystate(68, Ics, Line, Tlen+1, Action, Alen);
yystate(76, [C|Ics], Line, Tlen, Action, Alen) when C >= 97, C =< 122 ->
    yystate(52, Ics, Line, Tlen+1, Action, Alen);
yystate(76, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,76};
yystate(75, [85|Ics], Line, Tlen, Action, Alen) ->
    yystate(91, Ics, Line, Tlen+1, Action, Alen);
yystate(75, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,75};
yystate(74, [73|Ics], Line, Tlen, Action, Alen) ->
    yystate(90, Ics, Line, Tlen+1, Action, Alen);
yystate(74, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,74};
yystate(73, [86|Ics], Line, Tlen, Action, Alen) ->
    yystate(35, Ics, Line, Tlen+1, Action, Alen);
yystate(73, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,73};
yystate(72, [73|Ics], Line, Tlen, Action, Alen) ->
    yystate(80, Ics, Line, Tlen+1, Action, Alen);
yystate(72, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,72};
yystate(71, [84|Ics], Line, Tlen, Action, Alen) ->
    yystate(39, Ics, Line, Tlen+1, Action, Alen);
yystate(71, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,71};
yystate(70, [85|Ics], Line, Tlen, Action, Alen) ->
    yystate(54, Ics, Line, Tlen+1, Action, Alen);
yystate(70, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,70};
yystate(69, [80|Ics], Line, Tlen, Action, Alen) ->
    yystate(57, Ics, Line, Tlen+1, Action, Alen);
yystate(69, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,69};
yystate(68, [42|Ics], Line, Tlen, _, _) ->
    yystate(68, Ics, Line, Tlen+1, 7, Tlen);
yystate(68, [43|Ics], Line, Tlen, _, _) ->
    yystate(68, Ics, Line, Tlen+1, 7, Tlen);
yystate(68, [33|Ics], Line, Tlen, _, _) ->
    yystate(68, Ics, Line, Tlen+1, 7, Tlen);
yystate(68, [C|Ics], Line, Tlen, _, _) when C >= 60, C =< 62 ->
    yystate(68, Ics, Line, Tlen+1, 7, Tlen);
yystate(68, Ics, Line, Tlen, _, _) ->
    {7,Tlen,Ics,Line,68};
yystate(67, [67|Ics], Line, Tlen, _, _) ->
    yystate(12, Ics, Line, Tlen+1, 0, Tlen);
yystate(67, Ics, Line, Tlen, _, _) ->
    {0,Tlen,Ics,Line,67};
yystate(66, [83|Ics], Line, Tlen, Action, Alen) ->
    yystate(50, Ics, Line, Tlen+1, Action, Alen);
yystate(66, [76|Ics], Line, Tlen, Action, Alen) ->
    yystate(34, Ics, Line, Tlen+1, Action, Alen);
yystate(66, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,66};
yystate(65, [80|Ics], Line, Tlen, Action, Alen) ->
    yystate(12, Ics, Line, Tlen+1, Action, Alen);
yystate(65, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,65};
yystate(64, [79|Ics], Line, Tlen, Action, Alen) ->
    yystate(48, Ics, Line, Tlen+1, Action, Alen);
yystate(64, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,64};
yystate(63, [76|Ics], Line, Tlen, Action, Alen) ->
    yystate(75, Ics, Line, Tlen+1, Action, Alen);
yystate(63, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,63};
yystate(62, [84|Ics], Line, Tlen, Action, Alen) ->
    yystate(74, Ics, Line, Tlen+1, Action, Alen);
yystate(62, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,62};
yystate(61, [73|Ics], Line, Tlen, Action, Alen) ->
    yystate(73, Ics, Line, Tlen+1, Action, Alen);
yystate(61, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,61};
yystate(60, [73|Ics], Line, Tlen, Action, Alen) ->
    yystate(44, Ics, Line, Tlen+1, Action, Alen);
yystate(60, [72|Ics], Line, Tlen, Action, Alen) ->
    yystate(3, Ics, Line, Tlen+1, Action, Alen);
yystate(60, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,60};
yystate(59, [89|Ics], Line, Tlen, Action, Alen) ->
    yystate(12, Ics, Line, Tlen+1, Action, Alen);
yystate(59, [68|Ics], Line, Tlen, Action, Alen) ->
    yystate(12, Ics, Line, Tlen+1, Action, Alen);
yystate(59, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,59};
yystate(58, [69|Ics], Line, Tlen, Action, Alen) ->
    yystate(78, Ics, Line, Tlen+1, Action, Alen);
yystate(58, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,58};
yystate(57, [68|Ics], Line, Tlen, Action, Alen) ->
    yystate(41, Ics, Line, Tlen+1, Action, Alen);
yystate(57, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,57};
yystate(56, [77|Ics], Line, Tlen, Action, Alen) ->
    yystate(72, Ics, Line, Tlen+1, Action, Alen);
yystate(56, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,56};
yystate(55, [68|Ics], Line, Tlen, _, _) ->
    yystate(39, Ics, Line, Tlen+1, 0, Tlen);
yystate(55, Ics, Line, Tlen, _, _) ->
    {0,Tlen,Ics,Line,55};
yystate(54, [82|Ics], Line, Tlen, Action, Alen) ->
    yystate(38, Ics, Line, Tlen+1, Action, Alen);
yystate(54, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,54};
yystate(53, [82|Ics], Line, Tlen, Action, Alen) ->
    yystate(37, Ics, Line, Tlen+1, Action, Alen);
yystate(53, [65|Ics], Line, Tlen, Action, Alen) ->
    yystate(9, Ics, Line, Tlen+1, Action, Alen);
yystate(53, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,53};
yystate(52, [95|Ics], Line, Tlen, _, _) ->
    yystate(52, Ics, Line, Tlen+1, 2, Tlen);
yystate(52, [46|Ics], Line, Tlen, _, _) ->
    yystate(52, Ics, Line, Tlen+1, 2, Tlen);
yystate(52, [34|Ics], Line, Tlen, _, _) ->
    yystate(52, Ics, Line, Tlen+1, 2, Tlen);
yystate(52, [C|Ics], Line, Tlen, _, _) when C >= 48, C =< 57 ->
    yystate(52, Ics, Line, Tlen+1, 2, Tlen);
yystate(52, [C|Ics], Line, Tlen, _, _) when C >= 97, C =< 122 ->
    yystate(52, Ics, Line, Tlen+1, 2, Tlen);
yystate(52, Ics, Line, Tlen, _, _) ->
    {2,Tlen,Ics,Line,52};
yystate(51, [65|Ics], Line, Tlen, Action, Alen) ->
    yystate(63, Ics, Line, Tlen+1, Action, Alen);
yystate(51, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,51};
yystate(50, [67|Ics], Line, Tlen, Action, Alen) ->
    yystate(12, Ics, Line, Tlen+1, Action, Alen);
yystate(50, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,50};
yystate(49, [73|Ics], Line, Tlen, Action, Alen) ->
    yystate(78, Ics, Line, Tlen+1, Action, Alen);
yystate(49, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,49};
yystate(48, [73|Ics], Line, Tlen, Action, Alen) ->
    yystate(32, Ics, Line, Tlen+1, Action, Alen);
yystate(48, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,48};
yystate(47, [82|Ics], Line, Tlen, Action, Alen) ->
    yystate(80, Ics, Line, Tlen+1, Action, Alen);
yystate(47, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,47};
yystate(46, [83|Ics], Line, Tlen, Action, Alen) ->
    yystate(62, Ics, Line, Tlen+1, Action, Alen);
yystate(46, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,46};
yystate(45, [83|Ics], Line, Tlen, Action, Alen) ->
    yystate(61, Ics, Line, Tlen+1, Action, Alen);
yystate(45, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,45};
yystate(44, [84|Ics], Line, Tlen, Action, Alen) ->
    yystate(28, Ics, Line, Tlen+1, Action, Alen);
yystate(44, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,44};
yystate(43, [95|Ics], Line, Tlen, _, _) ->
    yystate(52, Ics, Line, Tlen+1, 1, Tlen);
yystate(43, [46|Ics], Line, Tlen, _, _) ->
    yystate(52, Ics, Line, Tlen+1, 1, Tlen);
yystate(43, [34|Ics], Line, Tlen, _, _) ->
    yystate(52, Ics, Line, Tlen+1, 1, Tlen);
yystate(43, [C|Ics], Line, Tlen, _, _) when C >= 48, C =< 57 ->
    yystate(43, Ics, Line, Tlen+1, 1, Tlen);
yystate(43, [C|Ics], Line, Tlen, _, _) when C >= 97, C =< 122 ->
    yystate(52, Ics, Line, Tlen+1, 1, Tlen);
yystate(43, Ics, Line, Tlen, _, _) ->
    {1,Tlen,Ics,Line,43};
yystate(42, [84|Ics], Line, Tlen, Action, Alen) ->
    yystate(12, Ics, Line, Tlen+1, Action, Alen);
yystate(42, [76|Ics], Line, Tlen, Action, Alen) ->
    yystate(58, Ics, Line, Tlen+1, Action, Alen);
yystate(42, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,42};
yystate(41, [65|Ics], Line, Tlen, Action, Alen) ->
    yystate(18, Ics, Line, Tlen+1, Action, Alen);
yystate(41, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,41};
yystate(40, [73|Ics], Line, Tlen, Action, Alen) ->
    yystate(56, Ics, Line, Tlen+1, Action, Alen);
yystate(40, [69|Ics], Line, Tlen, Action, Alen) ->
    yystate(88, Ics, Line, Tlen+1, Action, Alen);
yystate(40, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,40};
yystate(39, [69|Ics], Line, Tlen, Action, Alen) ->
    yystate(23, Ics, Line, Tlen+1, Action, Alen);
yystate(39, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,39};
yystate(38, [78|Ics], Line, Tlen, Action, Alen) ->
    yystate(22, Ics, Line, Tlen+1, Action, Alen);
yystate(38, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,38};
yystate(37, [79|Ics], Line, Tlen, Action, Alen) ->
    yystate(25, Ics, Line, Tlen+1, Action, Alen);
yystate(37, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,37};
yystate(36, [C|Ics], Line, Tlen, _, _) when C >= 48, C =< 57 ->
    yystate(36, Ics, Line, Tlen+1, 8, Tlen);
yystate(36, Ics, Line, Tlen, _, _) ->
    {8,Tlen,Ics,Line,36};
yystate(35, [69|Ics], Line, Tlen, Action, Alen) ->
    yystate(12, Ics, Line, Tlen+1, Action, Alen);
yystate(35, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,35};
yystate(34, [69|Ics], Line, Tlen, Action, Alen) ->
    yystate(18, Ics, Line, Tlen+1, Action, Alen);
yystate(34, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,34};
yystate(33, [76|Ics], Line, Tlen, Action, Alen) ->
    yystate(49, Ics, Line, Tlen+1, Action, Alen);
yystate(33, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,33};
yystate(32, [78|Ics], Line, Tlen, Action, Alen) ->
    yystate(12, Ics, Line, Tlen+1, Action, Alen);
yystate(32, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,32};
yystate(31, [69|Ics], Line, Tlen, Action, Alen) ->
    yystate(47, Ics, Line, Tlen+1, Action, Alen);
yystate(31, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,31};
yystate(30, [79|Ics], Line, Tlen, Action, Alen) ->
    yystate(12, Ics, Line, Tlen+1, Action, Alen);
yystate(30, [73|Ics], Line, Tlen, Action, Alen) ->
    yystate(46, Ics, Line, Tlen+1, Action, Alen);
yystate(30, [69|Ics], Line, Tlen, Action, Alen) ->
    yystate(66, Ics, Line, Tlen+1, Action, Alen);
yystate(30, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,30};
yystate(29, [82|Ics], Line, Tlen, Action, Alen) ->
    yystate(45, Ics, Line, Tlen+1, Action, Alen);
yystate(29, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,29};
yystate(28, [72|Ics], Line, Tlen, Action, Alen) ->
    yystate(12, Ics, Line, Tlen+1, Action, Alen);
yystate(28, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,28};
yystate(27, Ics, Line, Tlen, _, _) ->
    {6,Tlen,Ics,Line};
yystate(26, [69|Ics], Line, Tlen, Action, Alen) ->
    yystate(42, Ics, Line, Tlen+1, Action, Alen);
yystate(26, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,26};
yystate(25, [77|Ics], Line, Tlen, Action, Alen) ->
    yystate(12, Ics, Line, Tlen+1, Action, Alen);
yystate(25, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,25};
yystate(24, [76|Ics], Line, Tlen, Action, Alen) ->
    yystate(12, Ics, Line, Tlen+1, Action, Alen);
yystate(24, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,24};
yystate(23, [82|Ics], Line, Tlen, Action, Alen) ->
    yystate(12, Ics, Line, Tlen+1, Action, Alen);
yystate(23, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,23};
yystate(22, [73|Ics], Line, Tlen, Action, Alen) ->
    yystate(14, Ics, Line, Tlen+1, Action, Alen);
yystate(22, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,22};
yystate(21, [70|Ics], Line, Tlen, Action, Alen) ->
    yystate(33, Ics, Line, Tlen+1, Action, Alen);
yystate(21, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,21};
yystate(20, [C|Ics], Line, Tlen, Action, Alen) when C >= 48, C =< 57 ->
    yystate(36, Ics, Line, Tlen+1, Action, Alen);
yystate(20, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,20};
yystate(19, [82|Ics], Line, Tlen, Action, Alen) ->
    yystate(35, Ics, Line, Tlen+1, Action, Alen);
yystate(19, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,19};
yystate(18, [84|Ics], Line, Tlen, Action, Alen) ->
    yystate(35, Ics, Line, Tlen+1, Action, Alen);
yystate(18, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,18};
yystate(17, [85|Ics], Line, Tlen, Action, Alen) ->
    yystate(29, Ics, Line, Tlen+1, Action, Alen);
yystate(17, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,17};
yystate(16, [83|Ics], Line, Tlen, Action, Alen) ->
    yystate(12, Ics, Line, Tlen+1, Action, Alen);
yystate(16, [78|Ics], Line, Tlen, Action, Alen) ->
    yystate(0, Ics, Line, Tlen+1, Action, Alen);
yystate(16, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,16};
yystate(15, [79|Ics], Line, Tlen, Action, Alen) ->
    yystate(12, Ics, Line, Tlen+1, Action, Alen);
yystate(15, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,15};
yystate(14, [78|Ics], Line, Tlen, Action, Alen) ->
    yystate(1, Ics, Line, Tlen+1, Action, Alen);
yystate(14, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,14};
yystate(13, [78|Ics], Line, Tlen, Action, Alen) ->
    yystate(21, Ics, Line, Tlen+1, Action, Alen);
yystate(13, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,13};
yystate(12, Ics, Line, Tlen, _, _) ->
    {0,Tlen,Ics,Line};
yystate(11, Ics, Line, Tlen, _, _) ->
    {4,Tlen,Ics,Line};
yystate(10, [85|Ics], Line, Tlen, Action, Alen) ->
    yystate(35, Ics, Line, Tlen+1, Action, Alen);
yystate(10, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,10};
yystate(9, [76|Ics], Line, Tlen, Action, Alen) ->
    yystate(6, Ics, Line, Tlen+1, Action, Alen);
yystate(9, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,9};
yystate(8, [76|Ics], Line, Tlen, Action, Alen) ->
    yystate(24, Ics, Line, Tlen+1, Action, Alen);
yystate(8, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,8};
yystate(7, [85|Ics], Line, Tlen, Action, Alen) ->
    yystate(8, Ics, Line, Tlen+1, Action, Alen);
yystate(7, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,7};
yystate(6, [83|Ics], Line, Tlen, Action, Alen) ->
    yystate(35, Ics, Line, Tlen+1, Action, Alen);
yystate(6, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,6};
yystate(5, [82|Ics], Line, Tlen, Action, Alen) ->
    yystate(10, Ics, Line, Tlen+1, Action, Alen);
yystate(5, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,5};
yystate(4, Ics, Line, Tlen, _, _) ->
    {3,Tlen,Ics,Line};
yystate(3, [69|Ics], Line, Tlen, Action, Alen) ->
    yystate(19, Ics, Line, Tlen+1, Action, Alen);
yystate(3, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,3};
yystate(2, [79|Ics], Line, Tlen, Action, Alen) ->
    yystate(13, Ics, Line, Tlen+1, Action, Alen);
yystate(2, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,2};
yystate(1, [71|Ics], Line, Tlen, Action, Alen) ->
    yystate(12, Ics, Line, Tlen+1, Action, Alen);
yystate(1, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,1};
yystate(0, [84|Ics], Line, Tlen, Action, Alen) ->
    yystate(15, Ics, Line, Tlen+1, Action, Alen);
yystate(0, [83|Ics], Line, Tlen, Action, Alen) ->
    yystate(31, Ics, Line, Tlen+1, Action, Alen);
yystate(0, [78|Ics], Line, Tlen, Action, Alen) ->
    yystate(39, Ics, Line, Tlen+1, Action, Alen);
yystate(0, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,0};
yystate(S, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,S}.

%% yyaction(Action, TokenLength, TokenChars, TokenLine) ->
%% {token,Token} | {end_token, Token} | skip_token | {error,String}.
%% Generated action function.

yyaction(0, TokenLen, YYtcs, TokenLine) ->
    TokenChars = yypre(YYtcs, TokenLen),
    yyaction_0(TokenChars, TokenLine);
yyaction(1, TokenLen, YYtcs, TokenLine) ->
    TokenChars = yypre(YYtcs, TokenLen),
    yyaction_1(TokenChars, TokenLine);
yyaction(2, TokenLen, YYtcs, TokenLine) ->
    TokenChars = yypre(YYtcs, TokenLen),
    yyaction_2(TokenChars, TokenLine);
yyaction(3, _, _, TokenLine) ->
    yyaction_3(TokenLine);
yyaction(4, _, _, TokenLine) ->
    yyaction_4(TokenLine);
yyaction(5, _, _, _) ->
    yyaction_5();
yyaction(6, _, _, TokenLine) ->
    yyaction_6(TokenLine);
yyaction(7, TokenLen, YYtcs, TokenLine) ->
    TokenChars = yypre(YYtcs, TokenLen),
    yyaction_7(TokenChars, TokenLine);
yyaction(8, TokenLen, YYtcs, TokenLine) ->
    TokenChars = yypre(YYtcs, TokenLen),
    yyaction_8(TokenChars, TokenLine);
yyaction(_, _, _, _) -> error.

-compile({inline,yyaction_0/2}).
-file("src/sql_lexer.xrl", 13).
yyaction_0(TokenChars, TokenLine) ->
     { token, { keyword, TokenLine, TokenChars } } .

-compile({inline,yyaction_1/2}).
-file("src/sql_lexer.xrl", 14).
yyaction_1(TokenChars, TokenLine) ->
     { token, { integer, TokenLine, TokenChars } } .

-compile({inline,yyaction_2/2}).
-file("src/sql_lexer.xrl", 15).
yyaction_2(TokenChars, TokenLine) ->
     { token, { name, TokenLine, TokenChars } } .

-compile({inline,yyaction_3/1}).
-file("src/sql_lexer.xrl", 16).
yyaction_3(TokenLine) ->
     { token, { paren_open, TokenLine } } .

-compile({inline,yyaction_4/1}).
-file("src/sql_lexer.xrl", 17).
yyaction_4(TokenLine) ->
     { token, { paren_close, TokenLine } } .

-compile({inline,yyaction_5/0}).
-file("src/sql_lexer.xrl", 18).
yyaction_5() ->
     skip_token .

-compile({inline,yyaction_6/1}).
-file("src/sql_lexer.xrl", 19).
yyaction_6(TokenLine) ->
     { token, { separator, TokenLine } } .

-compile({inline,yyaction_7/2}).
-file("src/sql_lexer.xrl", 20).
yyaction_7(TokenChars, TokenLine) ->
     { token, { operator, TokenLine, TokenChars } } .

-compile({inline,yyaction_8/2}).
-file("src/sql_lexer.xrl", 22).
yyaction_8(TokenChars, TokenLine) ->
     { token, { variable, TokenLine, TokenChars } } .

-file("/usr/local/Cellar/erlang/20.3.4/lib/erlang/lib/parsetools-2.1.6/include/leexinc.hrl", 313).
