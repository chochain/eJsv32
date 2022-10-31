\ eJ32a.f
: code CODE ;
: ::   CODE ;
: ;; return ; 

CRR .( Chararter IO ) CRR
:: ?KEY  erxbfull @ ;;
:: KEY   begin erxbfull @ until erxbuf @ ;;      
:: EMIT  begin etxbempty  @ until etxbuf  ! ;;

CRR .( Common functions ) CRR
:: U< ( u u -- t ) 2DUP XOR 0< if SWAP DROP 0< EXIT then - 0< ;;
::  < ( n n -- t ) 2DUP XOR 0< if      DROP 0< EXIT then - 0< ;;
:: MAX ( n n -- n ) 2DUP      < if SWAP then DROP ;;
:: MIN ( n n -- n ) 2DUP SWAP < if SWAP then DROP ;;
:: WITHIN ( u ul uh -- t ) \ ul <= u < uh
   OVER - >R - R> U< ;;
:: /MOD ( n n -- r q )
   2DUP / >R MOD R> ;;
:: */ ( n n n -- q ) 
   >R * R> / ;;

CRR .( Memory access ) CRR
:: EXECUTE ( a ) istore_3 3 ret ;;
:: HERE ( -- a ) CP @ ;;
:: PAD ( -- a ) CP @ 50 LIT + ;;
:: CMOVE ( b b u -- ) 
  FOR AFT istore_3 DUP C@ iload_3 C! 1+ iload_3 1+
  THEN NEXT 2DROP ;;
:: FILL ( b u c -- ) 
  SWAP FOR SWAP AFT 2DUP C! 1+ THEN NEXT 2DROP ;;

CRR .( Numeric Output ) CRR \ single precision
:: DIGIT ( u -- c )
  9 LIT OVER < 7 LIT AND +
  ( CHAR 0 ) 30 LIT + ;;
:: EXTRACT ( n base -- n c )
  /MOD SWAP DIGIT ;;
:: <# ( -- ) PAD HLD ! ;;
:: HOLD ( c -- ) HLD @ 1- DUP HLD ! C! ;;
:: # ( u -- u ) BASE @ EXTRACT HOLD ;;
:: #S ( u -- 0 ) BEGIN # DUP WHILE REPEAT ;;
CRR
:: SIGN ( n -- ) 0< IF ( CHAR - ) 2D LIT HOLD THEN ;;
:: #> ( w -- b u ) DROP HLD @ PAD OVER - ;;
:: str ( n -- b u ) DUP >R ABS <# #S R> SIGN #> ;;
:: HEX ( -- ) 10 LIT BASE ! ;;
:: DECIMAL ( -- ) 0A LIT BASE ! ;;

CRR .( Basic I/O ) CRR
:: SPACE ( -- ) BL EMIT ;;
:: SPACES ( +n -- ) FOR AFT SPACE THEN NEXT ;;
:: >CHAR ( c -- c )
  $7E LIT MIN BL MAX ;;
:: TYPE ( b u -- )
  FOR AFT COUNT >CHAR EMIT
  THEN NEXT DROP ;;
:: CR ( -- ) ( =Cr )
  0A LIT 0D LIT EMIT EMIT ;;
:: do$ ( -- a , get prior frame )
  4 iload DUP COUNT + 4 istore ;; 

CRR
:: $"| ( -- a ) do$ ;; 
:: ."| ( -- ) do$ COUNT TYPE ;;
::  .R ( n +n -- )
  >R str R> OVER - SPACES TYPE ;;
::  . ( n -- )
  str SPACE TYPE ;;
:: ? ( a -- ) @ . ;;

CRR .( Numeric Input ) CRR \ single precision
:: DIGIT? ( c base -- u t )
  >R ( CHAR 0 ) 30 LIT - 9 LIT OVER <
  IF 7 LIT - DUP 0A LIT  < OR THEN DUP R> U< ;;
:: NUMBER? ( a -- n T | a F )
  DUP istore_3 COUNT istore_1 ( a+1 )
  COUNT ( a+2 c - ) DUP 2D LIT = ( a+2 c f )
  IF iconst_m1 istore_2 DROP ( a+2 )
    iload_1 1- ( a+2 n-1 )
  ELSE DROP 1- iload_1 ( a+1 n )
  THEN iconst_0 tmp !
  FOR AFT ( a' )
    COUNT ( a'+1 c ) BASE @ DIGIT? ( a'+1 b  f )
    IF tmp @ BASE @ * + tmp !
    ELSE 2DROP iload_3 iconst_0 ( a 0 ) EXIT THEN
  THEN NEXT
  DROP tmp @ ( u ) iload_2 IF NEGATE THEN
  iconst_m1 ;; ( u t )

CRR .( Parsing ) CRR
:: PARSE ( c a -- a-1 )
  DUP tmp ! >IN ! ( c )
  BEGIN KEY DUP EMIT DUP >IN @ C! $21 LIT > UNTIL
  BEGIN iconst_1 >IN +! ( c )
    KEY DUP EMIT 2DUP XOR ( c k f1 ) 
    OVER $1F LIT > ( c k f1 f2 ) AND ( c k f )
  WHILE >IN @ C! ( c )
  REPEAT ( c k )
  2DROP tmp @ >IN @ OVER - ( a n )
  SWAP 1- SWAP ( a-1 n )
  OVER C! ( a-1 )
  ;;
:: TOKEN ( -- a , parser buffer )
  BL CP @ iconst_3 + PARSE  ;; 
:: WORD ( c -- a , word buffer )
  CP @ 1+ PARSE ;;

CRR .( Dictionary Search ) CRR
:: NAME> ( na -- ca ) COUNT 1F LIT AND +  ;;
:: SAME? ( a na -- a na diff ) 
  OVER W@ OVER W@ ( a na ca cna ) 
  $FF1F ldi AND XOR ?DUP IF EXIT ( a na diff ) THEN
  OVER C@ 1- >R ( a na )
  OVER 2+ OVER 2+ R> ( a na a+1 na+1 length ) 
  FOR AFT OVER R@ + C@ ( a na a+i na+i ca ) 
    OVER R@ + C@ ( a na a+i na+i ca cna ) 
    XOR ( a na a+i na+i diff ) 
    IF DROP ( a na a+i ) EXIT THEN 
  THEN NEXT ( a na a+i na+i ) 
  2DROP iconst_0  ;; ( a na 0 ) 

:: NAME? ( a -- cfa nfa | a 0 )
  CONTEXT ( a va )
  BEGIN W@ DUP  ( a na na )
  WHILE ( a na )
    SAME? ( a na f )
    IF 2- ( a la ) DUP tmp ! ( save for see )
    ELSE SWAP DROP DUP NAME> SWAP EXIT ( ca na )
    THEN
  REPEAT ;; ( a 0 --, dictionary start )

CRR .( compiler ) CRR
:: [ ( -- )
  iconst_0 COMPI ! ;; IMMEDIATE
:: ] ( -- )
  iconst_m1 COMPI ! ;; 
:: , ( n -- ) HERE DUP CELL+ CP ! ! CP @ DP ! ;;
:: W, ( w -- ) HERE DUP 2+ CP ! W! CP @ DP ! ;;
:: C, ( c -- ) HERE DUP 1+ CP ! C! CP @ DP ! ;;
:: ALLOT ( n -- ) 
   FOR AFT iconst_0 C, THEN NEXT ;;
:: COMPIL ( w -- ) B6 LIT C, W, ;; 
:: LITERAL ( n ) 
   DUP 0< IF CB LIT C, , EXIT THEN
   DUP $100 ldi < IF 10 LIT C, C, EXIT THEN
   DUP $10000 ldi <
   IF 11 LIT C, W,
   ELSE CB LIT C, , 
   THEN ;; 

CRR ( outer interpreter )
:: OK ( -- )
  COMPI @ IF ELSE
    CR istore_1 istore_2 istore_3 DUP .
    iload_3 DUP . iload_2 DUP . iload_1 DUP . 
    ."| $LIT >OK " 
  THEN ;;
:: QUIT ( -- )
  [ ( interpret )
  BEGIN
    TOKEN ( a )
    NAME? ( ca na | a 0 )
    ?DUP ( ca na na | a 0 )
    IF ( ca na )
      C@ $80 LIT AND ( ca immd )
      IF ( ca ) EXECUTE 
      ELSE
        COMPI @ IF COMPIL ELSE EXECUTE THEN
      THEN
    ELSE ( a )
      NUMBER? ( n f | a 0 )
      IF ( n ) COMPI @ IF LITERAL THEN
      ELSE ( a ) 
        DP @ CP ! ( clean dictionary )
        SPACE COUNT TYPE $3F LIT EMIT CR [
      THEN 
    THEN 
    COMPI @ IF ELSE OK THEN
  AGAIN   
:: abort"| ( f -- )
  IF do$ COUNT TYPE QUIT THEN do$ DROP ;;
:: ERROR ( a -- )
  SPACE COUNT TYPE $3F LIT EMIT CR QUIT

CRR .( colon compiler ) CRR
:: COMPILE ( -- )
  iload_0 1+ DUP W@ COMPIL
  2+ istore_0 ;;
:: ?UNIQUE ( a -- a )
  DUP NAME?
  IF COUNT TYPE ."| $LIT reDef "
  THEN DROP ;;
:: $,n ( a -- )
  DUP @
  IF ?UNIQUE
    ( na) CP @ DP !
    ( na) DUP NAME> CP !
    ( na) DUP LAST ! \ for OVERT
    ( na) 2-
    ( la) CONTEXT @ SWAP W! EXIT
  THEN ERROR
:: OVERT ( -- ) LAST @ CONTEXT ! ;;
:: ; ( -- )
  B1 LIT C, [ OVERT ;; IMMEDIATE
:: : ( -- ; <string> )
  TOKEN $,n ] ;;

CRR .( Tools ) CRR
:: ' ( -- ca )
  TOKEN NAME? IF EXIT THEN
  ERROR
:: dm+ ( b u -- b+u )
  OVER 6 LIT .R SPACE
  FOR AFT DUP C@ 3 LIT .R 1+
  THEN NEXT ;;
:: DUMP ( b u -- )
  HEX  10 LIT /
  FOR AFT CR 10 LIT dm+ SPACE
    DUP 10 LIT - 10 LIT TYPE
  THEN NEXT DROP ;;

CRR
:: >NAME ( ca -- na | F )
  CONTEXT ( ca la )
  BEGIN W@ DUP ( ca na na )
  WHILE 2DUP NAME> ( ca na ca ca ) XOR
    IF 2- ( ca la )
    ELSE SWAP DROP EXIT ( na )
    THEN
  REPEAT SWAP DROP ( na=0 ) ;; 
:: ID ( a -- )
  COUNT $01F LIT AND TYPE SPACE ;;

CRR
:: SEE ( -- ; <string> )
  CR ' ( ca --, tmp has next la )
  BEGIN ( ca )
    COUNT DUP $B6 LIT XOR ( ca+1 b f )
    IF . SPACE
    ELSE DROP COUNT >R ( ca+2 )
      COUNT $100 ldi * R> + ( ca+3 w ) >NAME
      ?DUP IF ID ELSE $5F LIT EMIT SPACE THEN
      1+ ( ca+4 )
    THEN 
    DUP tmp @ > ( ca+4 )
  UNTIL DROP ;;
:: WORDS ( -- )
  CR CONTEXT
  BEGIN W@ ?DUP
  WHILE DUP ID 2-
  REPEAT CR ;;

CRR .( Hardware reset ) CRR
::   DIAGNOSE     ( - )
     -1234 ldi $10 LIT /MOD
     $65 LIT iconst_0 0< +
\     mask
\ 'F'  prove + 0<         
     -2 ldi 0<     \ -1
     4 LIT +     \ 3
     $43 LIT +       \ 'F'
\ 'o' logic: XOR AND OR
     $4F LIT $6F LIT XOR    \ 20h
     $F0 LIT AND
     $4F LIT OR
\ 'r' stack: DUP OVER SWAP DROP
      8 LIT 6 LIT SWAP
      OVER XOR 3 LIT AND AND
      $70 LIT +        \ 'r'
\ 't'-- prove BRANCH ?BRANCH
      iconst_0 IF $3F LIT THEN
      -1 ldi IF $74 LIT ELSE $21 LIT THEN
\ 'h' -- @ ! test memeory address
      $68 LIT $30 LIT !
      $30 LIT @
\ 'M' -- prove >R R> R@
      $4D LIT >R R@ R> AND
\ 'l'  -- prove 'next' can run
      $61 LIT $A LIT FOR iconst_1 + NEXT
\ 'S' -- prove 2!, 2@
      $50 LIT $3 LIT
      $30 LIT 2!
      $30 LIT 2@
      XOR
\ 'em' -- prove imul, idiv, irem
      $656D ldi $10000 ldi *
      DUP 1000000 ldi /
      swap $1000000 ldi MOD
      $10 LIT ishr
\ 'it' -- prove /, MOD
      $7469 ldi DUP $100 ldi MOD
      swap $100 ldi /
      ;;

CRR
:: COLD ( -- )
   DIAGNOSE
   CR ."| $LIT eJ32 v1.01"
   CR QUIT

CRR .( Structures ) CRR
:: BEGIN ( -- a ) HERE ;; IMMEDIATE
:: THEN ( A -- )  BEGIN SWAP W! ;; IMMEDIATE
:: FOR ( -- a )   3C LIT C, BEGIN ;; IMMEDIATE
CRR
:: NEXT ( a -- )  CA LIT C, W, ;; IMMEDIATE
:: UNTIL ( a -- ) 99 LIT C, W, ;; IMMEDIATE
:: AGAIN ( a -- ) A7 LIT C, W, ;; IMMEDIATE
:: IF ( -- A )    99 LIT C, BEGIN 0 LIT W, ;; IMMEDIATE
:: AHEAD ( -- A ) A7 LIT C, BEGIN 0 LIT W, ;; IMMEDIATE
CRR
:: REPEAT ( A a -- ) AGAIN THEN ;; IMMEDIATE
:: AFT ( a -- a A )  DROP AHEAD BEGIN SWAP ;; IMMEDIATE
:: ELSE ( A -- A )   AHEAD SWAP THEN ;; IMMEDIATE
:: WHILE ( a -- A a) IF SWAP ;; IMMEDIATE

CRR
:: $," ( -- ) ( CHAR " )
   22 LIT WORD DUP C@ + 1+ CP ! ;;
:: ABORT" ( -- ; <string> )
   B6 LIT C, forth_' abort"| >body forth_@ ldi W,
   $," ;; IMMEDIATE
:: $" ( -- ; <string> )
   B6 LIT C, forth_' $"| >body forth_@ ldi W,
   $," ;; IMMEDIATE
:: ." ( -- ; <string> ) 
   B6 LIT C, forth_' ."| >body forth_@ ldi W,
   $," ;; IMMEDIATE

CRR
:: DOCON popr @ ;;
:: DOVAR popr ;;
:: DOES ( -- ) popr LAST @ NAME> 1+ ! ;;
:: CODE ( -- ; <string> )
   TOKEN $,n OVERT ;;
:: CREATE ( -- ; <string> ) 
   CODE B6 LIT C, forth_' DOVAR >body forth_@ ldi W,
   CP @ DP ! ;;
:: VARIABLE ( -- ; <string> ) 
   CREATE 0 LIT , CP @ DP ! ;;
:: CONSTANT ( n --; <string> )
   CODE B6 LIT C, forth_' DOCON >body forth_@ ldi W,
   , CP @ DP ! ;;

CRR
(makehead) .( ( -- ) 29 LIT PARSE TYPE ;; IMMEDIATE
(makehead) ( 29 LIT PARSE 2DROP ;; IMMEDIATE
(makehead) IMMEDIATE $80 LIT LAST +! ;;

CRR
(makehead) EXIT return
(makehead) ! swap iastore return
(makehead) @ iaload return
(makehead) C! swap bastore return
(makehead) C@ baload return
(makehead) W! swap sastore return
(makehead) W@ saload return
(makehead) R> 5 iload return
(makehead) R@ 5 iload return
(makehead) >R 5 istore return

(makehead) SWAP swap return
(makehead) DROP pop return
(makehead) 2DROP pop2 return
(makehead) OVER dup2 pop return
(makehead) 2DUP dup2 return

(makehead) +  iadd return
(makehead) -  isub return
(makehead) *  imul return
(makehead) /  idiv return
(makehead) MOD  irem return
(makehead) OR  ior return
(makehead) AND  iand return
(makehead) XOR  ixor return
(makehead) NOT iconst_m1 ixor return
(makehead) NEGATE ineg return
(makehead) 1- iconst_m1 iadd return
(makehead) 1+ iconst_1 iadd return
(makehead) 2- iconst_2 isub return
(makehead) 2+ iconst_2 iadd return
(makehead) CELL- iconst_4 isub return
(makehead) CELL+ iconst_4 iadd return

(makehead) BL 20 LIT return
(makehead) +!
   dup istore_3 iaload iadd 
   iload_3 swap iastore return
(makehead) ROT
   istore_3 swap iload_3 swap return
(makehead) -ROT
   dup_x2 pop return
(makehead) 2!
   dup2 swap iastore swap pop
   iconst_4 iadd swap iastore return
(makehead) 2@
   dup iaload swap iconst_4 iadd iaload swap
   return
(makehead) COUNT 
   dup baload swap iconst_1 iadd swap return

(makehead) 0<
   ifneg iconst_0 else iconst_m1 then 
   return
(makehead) >
   ifgreat iconst_0 else iconst_m1 then
   return
(makehead) <
   ifless iconst_0 else iconst_m1 then
   return
(makehead) =
   ixor if iconst_0 else iconst_m1 then
   return
(makehead) ?DUP
   dup if dup then return
(makehead) ABS 
   dup ifneg else ineg then return
(makehead) DUP dup return

CRR

h forth_@ forth_dup forth_dup 

0 org 
COLD 0 #, 0 #, 0 #, 0 #,

$40 org
$10 #,
$0  #, 
$0  #, 
$0  #,
lasth forth_@ #,
( h )         #,
( h )         #,
( h )         #,



