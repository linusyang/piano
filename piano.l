/*
 * piano.l: A Piano Score Scanner
 * Linus Yang
 */

%{

#include <cstdio>
#include <string>
#include "piano.tab.h"

#define YY_DECL extern "C" int yylex()

%}

space                [ \t]*
integer              [0-9]+
octave               [drmfslt]
variable             [A-Z]
comment              #.*\n

%%

{integer}            { yylval.ival = atoi(yytext); return INT; }
{octave}             { yylval.cval = yytext[0]; return OCTAVE; }
{variable}           { yylval.cval = yytext[0]; return VAR; }

"_"                  return(FLAT);
"^"                  return(SHARP);
"-"                  return(TWOBEATS);
"--"                 return(THREEBEATS);
"---"                return(FOURBEATS);
"("                  return(LPAREN);
")"                  return(RPAREN);
"["                  return(LBRACKET);
"]"                  return(RBRACKET);
"{"                  return(LBRACE);
"}"                  return(RBRACE);
"="                  return(ASSIGN);
"$"                  return(REF);
";"                  return(SEMICOLON);
\n                   return(NEWLINE);

{space}              /* do nothing */
{comment}            /* do nothing */
.                    { std::fprintf(stderr, "ignore undefined symbol: %s\n", yytext); }

%%
