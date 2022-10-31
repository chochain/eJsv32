( meta32.f for weforth, 22mar02cht )

HEX
VARIABLE debugging?
\ 1 debugging? ! 

: .head ( addr -- addr )
   SPACE >IN @ 20 WORD COUNT TYPE >IN !
   DUP .
   ;

: cr CR
   debugging? @
   IF .S KEY 0D = ABORT" DONE"
   THEN
   ;

: forth_' ' ;
: forth_dup DUP ;
: forth_drop DROP ;
: forth_over OVER ;
: forth_swap SWAP ;
: forth_@ @ ;
: forth_! ! ;
: forth_and AND ;
: forth_+ + ;
: forth_- - ;
: forth_word WORD ;
: forth_words WORDS ;
: forth_.s .S ;
: CRR cr ;
: forth_.( [COMPILE] .( ;
: forth_count COUNT ;
: forth_r> R> ;
: -or   XOR ;
: >body 5 + ;
: forth_forget FORGET ;

CREATE ram  8000 ALLOT
: reset   ram 8000 0 FILL ; 
: ram@   ram +  @ ;
: ram!   ram +  ! ;
: ramw@  ram +  w@ ;
: ramw!  ram +  w! ;
: ramc@  ram +  c@ ;
: ramc!  ram +  c! ;
: binary 2 BASE ! ;
: FOUR   (  a -- a+16 ) 10 FOR AFT  DUP RAMC@ 3 U.R  1 + THEN NEXT
      10 - SPACE 10 FOR AFT  DUP RAMC@ 20 MAX 7E MIN EMIT 1 + THEN NEXT ;
: SHOW ( a -- a+256 )   10 FOR AFT  CR  DUP 7 .R SPACE
      FOUR THEN NEXT ;
: showram 0 $A FOR AFT SHOW THEN NEXT DROP ;

VARIABLE hFile
CREATE CRLF-ARRAY 0D C, 0A C,
: CRLF   
      hFile @ 
      CRLF-ARRAY 2
      PAD ( lpWrittenBytes )
      0 ( lpOverlapped )
      WriteFile
      IF ELSE ." write error" QUIT THEN
   ;

: open-mif-file
   Z" ej32c.coe" 
   $40000000 ( GENERIC_WRITE )
   0 ( share mode )
   0 ( security attribute )
   2 ( CREATE_ALWAYS )
   $80 ( FILE_ATTRIBUTE_NORMAL )
   0 ( hTemplateFile )
   CreateFileA hFile !
   ;
: write-mif-line
      PAD ( lpWrittenBytes )
      0 ( lpOverlapped )
      WriteFile
      IF ELSE ." write error" QUIT THEN
   CRLF
   ;
: write-mif-header
   CRLF
      hFile @ 
      $" memory_initialization_radix=16;" 
      PAD ( lpWrittenBytes )
      0 ( lpOverlapped )
      WriteFile
      IF ELSE ." write error" QUIT THEN
   CRLF
      hFile @ 
      $" memory_initialization_vector=" 
      PAD ( lpWrittenBytes )
      0 ( lpOverlapped )
      WriteFile
      IF ELSE ." write error" QUIT THEN
   ;
: write-mif-trailer
   CRLF
      hFile @ 
      $" ; " 
      PAD ( lpWrittenBytes )
      0 ( lpOverlapped )
      WriteFile
      IF ELSE ." write error" QUIT THEN
   ;

: write-mif-data
   0 ( initial ram location )
   $2000 FOR AFT
      CRLF
      hFile @ 
      OVER RAM@ 
      <# 2C HOLD 7 FOR # NEXT  #>
      PAD ( lpWrittenBytes )
      0 ( lpOverlapped )
      WriteFile
      IF ELSE ." write error" QUIT THEN
      1+
   THEN NEXT
   DROP ( discard ram location )
   ;

: close-mif-file
   hFile @ CloseHandle DROP
   ;

: write-mif-file
   open-mif-file
   write-mif-header
   write-mif-data
   close-mif-file
   ;

  
FLOAD asm32c.f 
$100 org
FLOAD kern32c.f
FLOAD ef32c.f
write-mif-file
 FLOAD sim32c.f


