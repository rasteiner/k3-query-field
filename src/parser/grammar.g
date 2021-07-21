%lex

%% 

\s+                      /* skip whitespace */
    
\btrue\b                 return 'TRUE'
\bfalse\b                return 'FALSE'
\bnull\b                 return 'NULL'
    
\(                       return 'LPAREN'
\)                       return 'RPAREN'
\[                       return 'LBRACKET'
\]                       return 'RBRACKET'
\,                       return 'COMMA'

\d*\.\d+                 return 'FLOAT'
\d+                      return 'INT'
\.                       return 'DOT'

[a-zA-Z0-9_]+            return 'IDENTIFIER'

\"(?:\\[\"\\]|[^\"\\])*\"   yytext = yytext.slice(1, -1); return 'STRING2';
\'(?:\\[\'\\]|[^\'\\])*\'   yytext = yytext.slice(1, -1); return 'STRING1';
/lex


%% 

Expression
    : IndexExpression
    ;

IndexExpression
    : MethodExpression
    | IndexExpression LBRACKET Expression RBRACKET { console.dir($$); $$ = [ 'subscript', [$1, $3] ] }
    ;

MethodExpression
    : AccessExpression
    | MethodExpression LPAREN RPAREN { $$ = ['method', [$1, []]] }
    | MethodExpression LPAREN List RPAREN { $$ = ['method', [$1, $3]] }
    ;

AccessExpression
    : AtomicExpression
    | IndexExpression DOT Identifier { $$ = ['access', [$1, $3]] }
    ;

AtomicExpression
    : LPAREN Expression RPAREN { $$ = $2 }
    | Literal
    | Identifier
    ;

Identifier
    : IDENTIFIER { $$ = ['id', $1] }
    ;

Literal
    : STRING1 { $$ = ['val', $1, "'"] }
    | STRING2 { $$ = ['val', $1, '"'] }
    | INT { $$ = ['val', parseInt($1)] }
    | FLOAT { $$ = ['val', parseFloat($1)] }
    | TRUE { $$ = ['val', true] }
    | FALSE { $$ = ['val', false] }
    | NULL { $$ = ['val', null] }
    | LBRACKET List RBRACKET { $$ = ['val', $2] }
    | LBRACKET RBRACKET { $$ = ['val', []] }
    ;

List
    : Expression { $$ = [ $1 ] }
    | List COMMA Expression { $1.push($3); $$ = $1; }
    ;
