package Perlscan;
## ABSTRACT:  Lexical analysis module for Perl -- parses one line of Perl program (which should contain a complete statement) into tokens/lexems
##          For alpha-testers only. Should be used with Pythoinizer testing suit
##
## Copyright Nikolai Bezroukov, 2019-2020.
## Licensed under Perl Artistic license
##
## REQURES
##        pythonizer.pl
##        Pythonizer.pm
##        Softpano.pm

#--- Development History
#
# Ver      Date        Who        Modification
# ====  ==========  ========  ==============================================================
# 0.10 2019/10/09  BEZROUN   Initial implementation
# 0.20 2019/11/13  BEZROUN   Tail comment is now treated as a special case and does not produce a lexem
# 0.30 2019/11/14  BEZROUN   Parsing of literals completly reorganized.
# 0.40 2019/11/14  BEZROUN   For now double quoted string are translatied into concatenation of components
# 0.50 2019/11/15  BEZROUN   Better parsing of Perl literals implemented
# 0.51 2019/11/19  BEZROUN   Problem of translation of ` ` (and rx() is that it is Python version dependent
# 0.52 2019/11/20  BEZROUN   Problem of translation of tr/abc/def/ solved
# 0.53 2019/12/20  BEZROUN   Here strings are now processed
# 0.60 2020/02/03  BEZROUN   Allow processing multiline statements
# 0.61 2020/02/03  BEZROUN   If the line does not ends with ; ){ or } we assume that the statement is continued on the next line
# 0.62 2020/05/16  BEZROUN   Nesting is performed from this module
# 0.63 2020/06/15  BEZROUN   Tail comments are artifically made properties of the last token in the line
# 0.64 2020/08/06  BEZROUN   gen_statement moved from pythonizer, ValCom became a local array
# 0.65 2020/08/08  BEZROUN   Diamond operator (<> <HANDLE>) is treated now as identifier
# 0.66 2020/08/09  BEZROUN   gen_chunk moved to Perlscan module. Pythoncode array made local
# 0.70 2020/08/10  BEZROUN   Postfix statements accomodated
# 0.71 2020/08/11  BEZROUN   scanning of regular expressions improved. / qr and 'm' are treated uniformly
# 0.72 2020/08/12  BEZROUN   Perl_default_var is renamed to default_var
# 0.73 2020/08/14  BEZROUN   Decoding of system variables in double quoted literals implemented
# 0.74 2020/08/18  BEZROUN   f-strings are generated for double quoted literals for Python 3.8
# 0.75 2020/08/25  BEZROUN   variable for other namespaces are recognized now
# 0.76 2020/08/27  BEZROUN   Special subroutine for putting regex in quote created
# 0.80 2020/08/31  BEZROUN   Handling of regex improved, keywords are added,
# 0.81 2020/08/31  BEZROUN   Handling of % improved.
# 0.82 2020/09/01  BEZROUN   my is eliminated, unless is the first token (for my $i...)
# 0.83 2020/09/02  BEZROUN   if regex contains both single and double quotes use """. Same for tranlation of double quoted
# 0.90 2020/09/17  BEZROUN   Adapted for detection of global identifiers.
# 0.91 2020/09/18  BEZROUN   ValType array added and now used in pass 0: values set to 'X' for special variables
#==start=============================================================================================
use v5.10;
use warnings;
use strict 'subs';
use feature 'state';
use Softpano qw(abend logme out);
#use Pythonizer qw(correct_nest getline prolog epilog output_line);
require Exporter;

our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

@ISA = qw(Exporter);
@EXPORT = qw(gen_statement tokenize gen_chunk @ValClass  @ValPerl  @ValPy @ValCom @ValType $TokenStr);
#our (@ValClass,  @ValPerl,  @ValPy, $TokenStr); # those are from main::

  $VERSION = '0.91';
  #
  # types of veraiables detected during the first pass; to be implemented later
  #
  #%is_numeric=();
#
# List of Perl special variables
#

   %SPECIAL_VAR=('O'=>'os.name','T'=>'OS_BASETIME', 'V'=>'sys.version[0]', 'X'=>'sys.executable()',
                 ';'=>'PERL_SUBSCRIPT_SEPARATOR','>'=>'UNIX_EUID','<'=>'UNIX_UID','('=>'os.getgid()',')'=>'os.getegid()',
                 '?'=>'subprocess_rc',);

   %logical_op=('and'=>'&&','or'=>'||','not'=>'!');

   %keyword_tr=('eq'=>'==','ne'=>'!=','lt'=>'<','gt'=>'>','le'=>'<=','ge'=>'>=',
                'x'=>' * ',
                'bless'=>'NoTrans!','BEGIN'=>'def begin():',
                'caller'=>'unknown','chdir'=>'.os.chdir','chmod'=>'.os.chmod','chomp'=>'.rstrip("\n")','chop'=>'[0:-1]','chr'=>'chr','close'=>'.f.close',
                'die'=>'raise', 'defined'=>'unknown', 'do'=>'','delete'=>'.pop(','defined'=>'perl_defined',
                'for'=>'for ','foreach'=>'for ',
                'else'=>'else: ','elsif'=>'elif ','eval'=>'NoTrans!', 'exit'=>'sys.exit','exists'=> 'in', # if  key in dictionary 'exists'=>'.has_key'
                'if'=>'if ', 'index'=>'.find',
                'grep'=>'filter', 'goto'=>'NoTrans!', 'getcwd'=>'os.getcwd',
                'join'=>'.join(',
                'keys'=>'.keys',
                'last'=>'break ','local'=>'','lc'=>'.lower()','length'=>'len','localtime'=>'.localtime',
                'map'=>'map', 'mkdir'=>'os.mkdir', 'my'=>'',
                'next'=>'continue ','no'=>'NoTrans!',
                'own'=>'global', 'oct'=>'eval','ord'=>'ord',
                'package'=>'NoTrans!','pop'=>'.pop()','push'=>'.extend(',
                'shift'=>'.pop(0)', 'split'=>'re.split','sort'=>'sort','scalar'=>'len', 'say'=>'print','state'=>'global','substr'=>'',
                   'sub'=>'def','STDERR'=>'sys.stderr','SYSIN'=>'sys.stdin','system'=>'os.system','sprintf'=>'',
                'rindex'=>'.rfind', 'require'=>'NoTrans!', 'ref'=>'type','rmdir'=>'os.rmdir',
                'unless'=>'if not ', 'until'=>'while not ','unlink'=>'os.unlink', 'use'=>'NoTrans!', 'uc'=>'.upper()', 'ucfirst'=>'.capitalize()',
                'STDERR'=>'sys.stderr','STDIN'=>'sys.stdin',  '__LINE__' =>'sys._getframe().f_lineno',
                'warn'=>'print',
                'ucfirst'=>'.capitalize()','uc'=>'.upper()','unshift'=>'.insert(0,',
               );

       %TokenType=('eq'=>'>','ne'=>'>','lt'=>'>','gt'=>'>','le'=>'>','ge'=>'>',
                   'x'=>'*',
                  'y'=>'q', 'q'=>'q','qq'=>'q','qr'=>'q','wq'=>'q','wr'=>'q','qx'=>'q','m'=>'q','s'=>'q','tr'=>'q',
                  'and'=>'0',
                  'caller'=>'f','chdir'=>'f','chomp'=>'f', 'chop'=>'f', 'chmod'=>'f','chr'=>'f','close'=>'f',
                  'default'=>'C','defined'=>'f','die'=>'f',
                  'else'=>'C', 'elsif'=>'C', 'exists'=>'f', 'exit'=>'C', 'export'=>'f',
                  'if'=>'c',  'index'=>'f',
                  'for'=>'c', 'foreach'=>'c',
                  'given'=>'c','grep'=>'f',
                  'join'=>'f',
                  'keys'=>'f',
                  'last'=>'C', 'lc'=>'f', 'length'=>'f', 'local'=>'t', 'localtime'=>'f',
                  'my'=>'t', 'map'=>'f', 'mkdir'=>'f',
                  'next'=>'C',
                  'or'=>'0', 'own'=>'t', 'oct'=>'f', 'ord'=>'f', 'open'=>'f',
                  'push'=>'f', 'pop'=>'f', 'print'=>'f', 'package'=>'c',
                  'rindex'=>'f','read'=>'f', 'return'=>'C', 'ref'=>'f',
                  'say'=>'f','scalar'=>'f','shift'=>'f', 'split'=>'f', 'sprintf'=>'f', 'sort'=>'f','system'=>'f', 'state'=>'t', 'sub'=>'k','substr'=>'f',
                  'values'=>'f',
                  'warn'=>'f', 'when'=>'C', 'while'=>'c',
                  'unless'=>'c', 'unshift'=>'f','until'=>'c','uc'=>'f', 'ucfirst'=>'f','use'=>'c',
                  );

#
# one to one translation of digramms. most are directly translatatble.
#
   %digram_tokens=('++'=>'^', '--'=>'^', '+='=>'=', '-='=>'=', '.='=>'=', '%='=>'=', '=~'=>'~','!~'=>'~',
                   '=='=>'>', '!='=>'>', '>='=>'>', '<='=>'>', # comparison
                   '=>'=>':', '->'=>'.',
                   '<<' => 'H', '>>'=>'=', '&&'=>'0', '||'=>'0',
                   '*='=>'=', '/='=>'/', '**'=>'*', '::'=>'.' ); #and/or/not

   %digram_map=('++'=>'+=1','--'=>'-=1','+='=>'+=', '*='=>'*=', '/='=>'/=', '.='=>'+=', '=~'=>'=','<>'=>'readline()','=>'=>': ','->'=>'.',
                '&&'=>' and ', '||'=>' or ','::'=>'.',
               );
my ($source,$cut,$tno)=('',0,0);
@PythonCode=(); # array for generated code chunks
#
# Tokenize line into one string and three arrays @ValClass  @ValPerl  @ValPy
#
sub tokenize
{
my ($l,$m);
      $source=$_[0];
      $tno=0;
      @ValClass=@ValCom=@ValPerl=@ValPy=@ValType=(); # "Token Type", token comment, Perl value, Py analog (if exists)
      $TokenStr='';
      if( $::debug > 3 && $main::breakpoint >= $.  ){
         $DB::single = 1;
      }
      while( $source ){
         ($source)=split(' ',$source,1);  # truncate white space on the left (Perl treats ' ' like AWK. )
         $s=substr($source,0,1);
         if( $s eq '#'  ){
            # plain vanilla tail comment
            if( $tno > 0  ){
               $tno--;
               $ValCom[$tno]=$source;
            }else{
                Pythonizer::output_line('',$source); # to block reproducing the first source line
            }
            $source=Pythonizer::getline();
            last if( $source=~/^\s*[;{}]\s*(#.*)?$/); # single closing statement symnol on the line.
            next;
         }elsif( $s eq ';' ){
            #
            # buffering tail is possible only if banace of round bracket is zero
            # because of for($i=0; $i<@x; $i++)
            #
            $balance=0;
            for ($i=0;$i<@ValClass;$i++ ){
               if( $ValClass[$i] eq '(' ){
                  $balance++;
               }elsif( $ValClass[$i] eq ')' ){
                  $balance--;
               }
            }
            if( $balance != 0  ){
               # for statement or similar situation
               $ValClass[$tno]=$ValPerl[$tno]=$s;
               $ValPy[$tno]=',';
               $cut=1; # we need to continue
            }else{
               # this is regular end of statement
               if( $tno>0 && $ValPerl[0] eq 'sub' ){
                  $ValPy[0]='#NoTrans!'; # this is a subroutne prototype, ignore it.
               }
               last if( length($source) == 1); # we got full statement; semicolon needs to be ignored.
               if( $source !~/^;\s*#/  ){
                  # there is some meaningful tail -- multiple statement on the line
                  Pythonizer::getline(substr($source,1)); # save tail that we be processed as the next line.
                  last;
               }else{
                  # comment after ; this is end of statement
                  if( $tno==0 ){
                     Pythonizer::getline(substr($source,1)); # save tail that we be processed as the next line.
                  }else{
                    $ValCom[$tno-1]=substr($source,1); # comment attributed to the last token
                  }
                  last; # we got full statement for analysis
               }
            }
        }
         # This is a meaningful symbol which tranlates into some token.
         $ValClass[$tno]=$ValPerl[$tno]=$ValPy[$tno]=$s;
         $ValCom[$tno]='';
         if( $s eq '}' ){
            # we treat '}' as a separate "dummy" statement -- eauvant to ';' plus change of nest -- Aug 7, 2020
            if( $tno==0  ){
                 # we recognize it as the end of the block if '}' is the first symbol
                if( length($source)>1 ){
                   Pythonizer::getline(substr($source,1)); # save tail
                   $source=$s; # this was we artifically create line with one symbol on it;
                }
                last; # we need to process it as a seperate one-symbol line
            }elsif( $tno>0 && length($source)==1 ){
                # NOTE: here $tno>0 and we reached the last symbol of the line
                # we recognize it as the end of the block
                #curvy bracket as the last symbol of the line
                Pythonizer::getline('}'); # make it a separate statement
                popup(); # kill the last symbol
                last; # we truncate '}' and will process it as the next line
            }
            # this is closing bracket of hash element
            $ValClass[$tno]=')';
            $ValPy[$tno]=']';
            $cut=1;

         }elsif( $s eq '{' ){
            # we treat '{' as the beginning of the block if it is the first or the last symbol on the line or is preceeded by ')' -- Aug 7, 2020
             if( $tno==0 ){
                if( length($source)>1  ){
                   Pythonizer::getline(substr($source,1)); # save tail
                }
                last; # artificially truncating the line making it one-symbol line
             }elsif( length($source)==1 ){
                # $tno>0 but line may came from buffer.
                # We recognize end of statemt only if previous token eq ')' to avod collision with #h{$s}
                Pythonizer::getline('{'); # make $tno==0 on the next iteration
                popup(); # eliminate '{' as it does not have tno==0
                last;
             }elsif( $ValClass[$tno-1] eq ')' || $source=~/^.\s*#/ || index($source,'}',1) == -1){
                # $tno>0 this is the case when curvy bracket has comments'
                Pythonizer::getline('{',substr($source,1)); # make it a new line to be proceeed later
                popup(); # eliminate '{' as it does not have tno==0
                last;
             }
            $ValClass[$tno]='('; # we treat anything inside curvy backets as expression
            $ValPy[$tno]='[';
            $cut=1;
         }elsif( $s eq '/' && ( $tno==0 || index('~(',$ValClass[$tno-1])>-1)  ){
              # slash means regex in following cases: if(/abc/ ){0}; $a=~/abc/; /abc/; split(/,/,$tst) REALLY CRAZY STAFF
              $ValClass[$tno]='q';
              $cut=single_quoted_literal($s,1);
              $ValPerl[$tno]=substr($source,1,$cut-2);
              $source=substr($source,$cut);
              $cut=0;
              if( $tno>=2 && $ValClass[$tno-2] eq 'f' ){
                 # in split regex should be plain vanilla -- no re.match is needed.
                 $ValPy[$tno]=put_regex_in_quotes( $ValPerl[$tno]); #  double quotes neeed to be escaped just in case
              }else{
                 $ValPy[$tno]=perl_match($ValPerl[$tno]); # there can be modifiers after the literal.
              }
         }elsif( $s eq "'"  ){
            #simple string, but backslashes of  are allowed
            $ValClass[$tno]='"';
            $cut=single_quoted_literal($s,1);
            $ValPerl[$tno]=substr($source,1,$cut-2);
            if( $tno>0 && $ValPerl[$tno-1] eq '<<'  ){
               # my $here_str = <<'END'; -- added Dec 20, 2019
               $tno--; # overwrite previous token; Dec 20, 2019 --NNB
               $ValPy[$tno]=Pythonizer::get_here($ValPerl[$tno]);
               $cut=length($source);
            }else{
               $ValPy[$tno]="'".escape_backslash($ValPerl[$tno])."'"; # only \n \t \r, etc needs to be  escaped
            }
         }elsif( $s eq '"'  ){
            $ValClass[$tno]='"';
            $cut=double_quoted_literal('"',1); # side affect populates $ValPy[$tno] and $ValPerl[$tno]
            if( $tno>0 && $ValPerl[$tno-1] eq '<<' ){
               # my $here_str = <<'END'; -- added Dec 20, 2019
               $tno--; # overwrite previous token; Dec 20, 2019 --NNB
               $ValClass[$tno]="'";
               $ValPerl[$tno]=substr($source,1,$cut-2); # we do not allow variables is here string.
               $ValPy[$tno]=Pythonizer::get_here($ValPerl[$tno]);
               $cut=length($source);
            }
         }elsif( $s eq '`'  ){
             $ValClass[$tno]='x';
             $cut=double_quoted_literal('`',1);
             $ValPy[$tno]=$ValPy[$tno];
         }elsif( $s=~/\d/  ){
            # processing of digits should preceed \w ad \w includes digits
            if( $source=~/(^\d+(?:[.e]\d+)?)/  ){
                $val=$1;
                #$ValType[$tno]='e';
            }elsif( $source=~/^(0x\w+)/  ){
               # need to add octal andhexadecila later
               $val=$1;
               #$ValType[$tno]='x';
            }elsif( $source=~/(0b\d+)/  ){
               #binary
               $val=$1;
               #$ValType[$tno]='b';
            }elsif(  $source=~/(\d+)/  ){
                $val=$1;
                #$ValType[$tno]='i';
            }
            $ValClass[$tno]='d';
            $ValPy[$tno]=$ValPerl[$tno]=$val;
            $cut=length($val);
        }elsif( $s=~/\w/  ){
            $source=~/^(\w+(\:\:\w+)*)/;
            $w=$1;
            $ValPerl[$tno]=$w;
            $cut=length($w);
            $ValClass[$tno]='i';
            $ValPy[$tno]=$w;
            if( exists($keyword_tr{$w}) ){
                $ValPy[$tno]=$keyword_tr{$w};
            }
            if( exists($TokenType{$w}) ){
               $class=$TokenType{$w};
               $ValClass[$tno]=$class;
               if( exists($logical_op{$w}) ){
                  substr($source,0,length($w)) = $logical_op{$w};
                  $tno-=1;
                  next; # rescan !!!
               }
               if( $class eq 'c' && $tno > 0 ){
                  # postfix conditional statement, like next if( line eq ''); Aug 10, 2020 --NNB
                   Pythonizer::getline('{',substr($_[0],0,length($_[0])-length($source)),'}'); # save head
                   @ValClass=@ValCom=@ValPerl=@ValPy=();
                   $tno=0;
                   next;
               }
              if( $class eq 't'  ){
                  if( $tno>0 && $w eq 'my' ){
                     $source=substr($source,2); # cut my in constucts like for(my $i=0...)
                     next;
                  }
                  $ValPy[$tno]='';
              }elsif( $class eq 'q' ){
                  # q can be tranlated into """", but qw actually is an expression
                  $delim=substr($source,length($w),1);

                  if( $w eq 'q' ){
                     $cut=single_quoted_literal($delim,2);
                     $ValPerl[$tno]=substr($source,length($w)+1,$cut-length($w)-2);
                     $w=escape_backslash($ValPerl[$tno]);
                     $ValPy[$tno]=escape_quotes($w,2);
                     $ValClass[$tno]='"';
                  }elsif( $w eq 'qq' ){
                     # decompose doublke quote populate $ValPy[$tno] as a side effect
                     $cut=double_quoted_literal($delim,length($w)+1); # side affect populates $ValPy[$tno] and $ValPerl[$tno]
                     $ValClass[$tno]='"';
                  }elsif( $w eq 'qx' ){
                     #executable, needs interpolation
                     $cut=double_quoted_literal($delim,length($w)+1);
                     $ValPy[$tno]=$ValPy[$tno];
                     $ValClass[$tno]='x';
                  }elsif( $w eq 'm' | $w eq 'qr' | $w eq 's' ){
                     $source=substr($source,length($w)+1); # cut the word and delimiter
                     $cut=single_quoted_literal($delim,0); # regex always ends before the delimiter
                     $arg1=substr($source,0,$cut-1);
                     $source=substr($source,$cut); #cut to symbol after the delimiter
                     $cut=0;
                     if( $w eq 'm' || ($w eq 'qr' &&  $ValClass[$tno-1] eq '~') ){
                        $ValClass[$tno]='q';
                        $ValPy[$tno]=perl_match($arg1); # it calls is_regex internally
                     }elsif( $w eq 'qr' && $tno>=2 && $ValClass[$tno-1] eq '(' && $ValPerl[$tno-2] eq 'split' ){
                         # in split regex should be  plain vanilla -- no re.match is needed.
                         $ValPy[$tno]='r'.$quoted_regex; #  double quotes neeed to be escaped just in case
                     }elsif( $w eq 's' ){
                        $ValPerl[$tno]='re';
                        $ValClass[$tno]='f';
                        # processing second part of 's'
                        if( $delim=~tr/{([<'/{([<'/ ){
                           # case tr[abc][cde]
                           $delim=substr($source,0,1); # new delimiter can be different from the old, althouth this is raraly used in Perl.
                           $source=substr($source,1,0); # remove delimiter
                        }
                        # now string is  /def/d or [def]
                        $cut=single_quoted_literal($delim,0);
                        $arg2=substr($source,0,$cut-1);
                        $source=substr($source,$cut);
                        $cut=0;
                        ($modifier,undef)=is_regex($arg2); # modifies $source as a side effect
                        if( length($modifier) > 1 ){
                           #regex with modifiers
                            $quoted_regex='re.compile('.put_regex_in_quotes($arg1)."$modifier)";
                        }else{
                           # No modifier
                           $quoted_regex=put_regex_in_quotes($arg1);
                        }
                        if( length($modifier)>0 ){
                           #this is regex
                           if( $tno>=1 && $ValClass[$tno-1] eq '~'   ){
                              # explisit s
                               $ValPy[$tno]='re.sub('.$quoted_regex.','.put_regex_in_quotes($arg2).','; #  double quotes neeed to be escaped just in case
                           }else{
                               $ValPy[$tno]=put_regex_in_quotes("re.match($quoted_regex,default_var)");
                           }
                        }else{
                           # this is string replace operation coded in Perl as regex substitution
                           $ValPy[$tno]='str.replace('.$quoted_regex.','.$quoted_regex.',1)';
                        }
                     }else{
                        abend("Internal error while analysing $w in line $. : $_[0]");
                     }
                  }elsif( $w eq 'tr' || $w eq 'y'  ){
                     # tr function has two parts; also can be named y
                     $source=substr($source,length($w)+1); # cut the word and delimiter
                     $cut=single_quoted_literal($delim,0);
                     $arg1=substr($source,0,$cut-1); # regex always ends before the delimiter
                     $source=substr($source,$cut); # remove first part of substitution exclufing including the delimeter
                     if( index('{([<',$delim) > -1 ){
                        # case tr[abc][cde]
                        $delim=substr($source,0,1); # new delimiter can be different from the old, althouth this is raraly used in Perl.
                        $source=substr($source,1,0); # remove delimiter
                     }
                     # now string is  /def/d or [def]
                     $cut=single_quoted_literal($delim,0);
                     $arg2=substr($source,0,$cut-1);
                     $source=substr($source,$cut);
                     if( $source=~/^(\w+)/ ){
                        $tr_modifier=$1;
                        $source=substr($source,length($1));
                     }else{
                        $tr_modifier='';
                     }
                     $cut=0;

                     $ValClass[$tno]='f';
                     $ValPerl[$tno]='tr';
                     if( $tr_modifier eq 'd' ){
                             $ValPy[$tno]=".maketrans('','',".put_regex_in_quotes($arg1).')'; # deletion via none
                     }elsif( $tr_modifier eq 's' ){
                          # sqeeze In Python should be done via Regular expressions
                            if( $arg2 eq '' || $arg1 eq $arg2  ){
                               $ValPerl[$tno]='re';
                               $ValPy[$tno]='re.sub('.put_regex_in_quotes("([$arg1])(\\1+)").",r'\\1'),"; # needs to be translated into  two statements
                            }else{
                               $ValPerl[$tno]='re';
                               if( $ValClass[$tno-2] eq 's' ){
                                   $ValPy[$tno]="$ValPy[$tno-2].translate($ValPy[$tno-2].maketrans(".put_regex_in_quotes($arg1).','.put_regex_in_quotes($arg2).')); ';
                                   $ValPy[$tno].='re.sub('.put_regex_in_quotes("([$arg2])(\\1+)").",r'\\1'),"; # needs to be translated into  two statements
                               }else{
                                   $::TrStatus=-255;
                                   $ValPy[$tno].='re.sub('.put_regex_in_quotes("([$arg2])(\\1+)").",r'\\1'),";
                                   logme('S',"The modifier $tr_modifier for tr function with non empty second arg ($arg2) requires preliminary invocation of translate. Please insert it manually ");
                               }
                            }
                     }elsif( $tr_modifier eq '' ){
                         #one typical case is usage of array element on the left side $main::tail[$a_end]=~tr/\n/ /;
                         $ValPy[$tno]='.maketrans('.put_regex_in_quotes($arg1).','.put_regex_in_quotes($arg2).')'; # needs to be translated into  two statements
                     }else{
                         $::TrStatus=-255;
                         logme('S',"The modifier $tr_modifier for tr function currently is not translatable. Manual translation requred ");
                     }

                  }elsif( $w eq 'qw' ){
                     # we can emulate it with split function, althouth wq is mainly compile time.
                      $cut=single_quoted_literal($delim,length($w)+1);
                      $ValPerl[$tno]=substr($source,length($w)+1,$cut-length($w)-2);
                      if( $ValPerl[0] eq 'use' ){
                         $ValPy[$tno]=$ValPerl[$tno];
                      }else{
                         $ValPy[$tno]='"'.$ValPerl[$tno].'".split(r"\s+")';
                      }
                  }
               }
            }
         }elsif( $s eq '$'  ){
            if( substr($source,0,length('$DB::single')) eq '$DB::single' ){
               # special case: $DB::single = 1;
               $ValPy[$tno]='pdb.set_trace';
               $ValClass[$tno]='f';
               $cut=index($source,';');
               substr($source,0,$cut)='perl_trace()'; # remove non-tranlatable part.
               $cut=length('perl_trace');
            }else{
               decode_scalar($source,1);
            }
         }elsif( $s eq '@'  ){
            if( substr($source,1)=~/^(\:?\:?\w+(\:\:\w+)*)/ ){
               $arg1=$1;
               if( $arg1 eq '_' ){
                  $ValPy[$tno]="perl_arg_array";
                  $ValType[$tno]="X";
               }elsif( $arg1 eq 'ARGV'  ){
                    $ValPy[$tno]='sys.argv';
                     $ValType[$tno]="X";
               }else{
                  if( $tno>=2 && $ValClass[$tno-2] =~ /[sd'"q]/  && $ValClass[$tno-1] eq '>'  ){
                     $ValPy[$tno]='len('.$arg1.')'; # scalar context
                     $ValType[$tno]="X";
                   }else{
                     $ValPy[$tno]=$arg1;
                  }
                  $ValPy[$tno]=~tr/:/./s;
                  if( substr($ValPy[$tno],0,1) eq '.' ){
                     $ValPy[$tno]='__main__'.$ValPy[$tno];
                     $ValType[$tno]="X";
                  }
               }
               $cut=length($arg1)+1;
               $ValPerl[$tno]=substr($source,$cut);
               $ValClass[$tno]='a'; #array
            }else{
               $cut=1;
            }
         }elsif( $s eq '%' ){
            # the problem here is that %2 can be in i=k%2, so we need to excude digits from regex  -- NNB Sept 3, 2020
            if( substr($source,1)=~/^(\:?\:?[_a-zA-Z]\w*(\:\:[_a-zA-Z]\w*)*)/ ){
               $cut=length($1)+1;
               $ValClass[$tno]='h'; #hash
               $ValPerl[$tno]=$1;
               $ValPy[$tno]=$1;
               $ValPy[$tno]=~tr/:/./s;
               if( substr($ValPy[$tno],0,1) eq '.' ){
                  $ValCom[$tno]='X';
                  $ValPy[$tno]='__main__'.$ValPy[$tno];
               }
            }else{
              $cut=1;
            }
         }elsif( $s eq '[' || $s eq '(' ){
            $ValClass[$tno]='('; # we treat anything inside curvy backets as expression
            $cut=1;
         }elsif( $s eq ']' || $s eq ')' ){
            $ValClass[$tno]=')'; # we treat anything inside curvy backets as expression
            $cut=1;
         }elsif( $s=~/\W/  ){
            #This is delimiter
            $digram=substr($source,0,2);
            if( exists($digram_tokens{$digram})  ){
               $ValClass[$tno]=$digram_tokens{$digram};
               $ValPerl[$tno]=$digram;
               if( $ValClass[$tno] eq '0' && $ValClass[$tno-1] eq ')' && $ValClass[0] =~ /[\(fi]/ ){
                  $balance=(join('',@ValClass)=~tr/()//);
                  if( $balance % 2 == 0 ){
                     # postfix conditional statement, like ($debug>0) && ( line eq ''); Aug 10, 2020 --NNB
                     Pythonizer::getline('{',substr($source,3),'}');
                     $source=substr($_[0],0,length($_[0])-length($source));
                     $source=$1 if( $source=~/(.+)\s+$/);
                     $prefix=($digram eq '&&') ? 'if( ' : ' if( ! ';
                     if( substr($source,0,1) eq '(' ){
                        substr($source,0,1)=$prefix;
                     }else{
                        $source=$prefix.$source.')';
                     }
                     @ValClass=@ValCom=@ValPerl=@ValPy=();
                     $tno=0; # rescan!!!
                     next;
                  }
                  $cut=2;
               }else{
                  if( exists($digram_map{$digram})  ){
                     $ValPy[$tno]=$digram_map{$digram}; # changes for Python
                  }else{
                     $ValPy[$tno]=$ValPerl[$tno]; # same as in Perl
                  }
                  $cut=2;
               }
            }elsif( $s eq '='  ){
               if( index(join('',@ValClass),'c')>-1 && $::PyV==3 ){
                  $ValPy[$tno]=':=';
               }
               $cut=1;
            }elsif( $s eq '\\'  ){
               $ValPy[$tno]='';
               $cut=1;
            }elsif( $s eq '!'  ){
               $ValPy[$tno]=' not ';
               $cut=1;
            }elsif( $s eq '-'  ){
              $s2=substr($source,1,1);
              if( ($k=index('fdlzes',$s2))>-1 && substr($source,2,1)=~/\s/  ){
                 $ValClass[$tno]='f';
                 $ValPerl[$tno]=$digram;
                 $ValPy[$tno]=('os.path.isfile','os.path.isdir','os.path.islink','not os.path.getsize','os.path.exists','os.stat.getsize')[$k];
                 $cut=2;
              }else{
                 $cut=1; # regular minus operator
              }
            }elsif( $s eq '<'  ){
               # diamond operator
               if( $source=~/^<(\w*)>/ ){
                  $ValClass[$tno]='i';
                  $cut=length($1)+2;
                  $ValPerl[$tno]="<$1>";
                  #
                  # Let's try to determine the context
                  #
                  if( $tno==2 && $ValClass[0] eq 'a' && $ValClass[1] eq '='){
                     if(length($1)==0 || $1 eq 'STDIN' ){
                        $ValPy[$tno]='sys.stdin.readlines()';
                     }else{
                        $ValPy[$tno]="$1.readlines()";
                     }
                  }else{
                      if(length($1)==0 || $1 eq 'STDIN' ){
                         $ValPy[$tno]='sys.stdin().readline()';
                      }else{
                         $ValPy[$tno]="$1.readline()";
                      }
                  }
               }else{
                 $ValClass[$tno]='>'; # regular < operator
                 $cut=1;
               }
            }else{
               $ValClass[$tno]=$ValPerl[$tno]=$ValPy[$tno]=$s;
               if( $s eq '.'  ){
                  $ValPy[$tno]=' + ';
               }elsif( $s eq '<'  ){
                  $ValClass[$tno]='>';
               }
               $cut=1;
            }
         }
         finish(); # subroutine that prepeares the next cycle
      } # while

      $TokenStr=join('',@ValClass);
      if( $::debug>=2 ){
         $num=($Pythonizer::Input_mode) ? sprintf('%4u',$.) : sprintf('%4u',$Pythonizer::InLineNo);
         say STDERR "\nLine $num. \$TokenStr: =|",$TokenStr, "|= \@ValPy: ",join(' ',@ValPy);
      }

} #tokenize
#
# subroutine that prepeares the next cycle
#
sub finish
{
   if( $cut>length($source)){
      logme('S',"The value of cut ($cut) exceeded the length (".length($source).") of the string: $source ");
      $source='';
   }elsif( $cut>0 ){
      substr($source,0,$cut)='';
   }
   if( length($source)==0  ){
       # the current line ended but ; or ){ } were not reached
       $source=Pythonizer::getline();
   }
   if( $::debug > 3  ){
     say STDERR "Lexem $tno Current token='$ValClass[$tno]' value='$ValPy[$tno]'", " Tokenstr |",join('',@ValClass),"| translated: ",join(' ',@ValPy);
   }
   $tno++;
}

sub decode_scalar
# Returns codes via variable $rc.-1 -special variable; 1 -regular variable
# NOTE: currently return value is not used. Aug 28, 2020 --NNB
# Has two modes of operation
#    update=1 -- set ValClass and ValPerl
#    update=0 -- set only ValPy
{
my $source=$_[0];
my $update=$_[1]; # if update is zero then only ValPy is updated
my $rc=-1;
   $s2=substr($source,1,1);
   if ( $update  ){
      $ValClass[$tno]='s'; # we do not need to set it if we are analysing double wuoted literal
   }
   if( $s2 eq '.'  ){
      # file line number
       $ValPy[$tno]='fileinput.filelineno()';
       $ValType[$tno]="X";
       $cut=2
   }elsif( $s2 eq '^'  ){
       $s3=substr($source,2,1);
       $cut=3;
       $ValType[$tno]="X";
       if( $s3=~/\w/  ){
          if( exists($SPECIAL_VAR{$s3}) ){
            $ValPy[$tno]=$SPECIAL_VAR{$s3};
          }else{
            $ValPy[$tno]='perl_special_var_'.$s3;
         }
       }
   }elsif( index(';<>()?',$s2) > -1  ){
      $ValPy[$tno]=$SPECIAL_VAR{$s2};
      $cut=2;
      $ValType[$tno]="X";
   }elsif( $s2 =~ /\d/ ){
       $source=~/^.(\d+)/;
       if( $update ){
          $ValPerl[$tno]=$1;
          $ValType[$tno]="X";
       }
       if( $s2 eq '0' ){
         $ValType[$tno]="X";
         $ValPy[$tno]="__file__";
       }else{
          $ValType[$tno]="X";
          $ValPy[$tno]="default_match.group($1)";
       }
       $cut=length($1)+1;
   }elsif( $s2 eq '#' ){
      $source=~/^..(\w+)/;
      $ValType[$tno]="X";
      if( $update ){
         $ValPerl[$tno]=$1;
      }
      $ValPy[$tno]='len('.$1.')-1';
      $cut=length($1)+2;
   }elsif( $source=~/^.(\w*(\:\:\w+)*)/ ){
      $cut=length($1)+1;
      $name=$1;
      $ValPy[$tno]=$name;
      if( $update ){
         $ValPerl[$tno]=substr($source,0,$cut);
      }
      if( ($k=index($name,'::')) > -1 ){
         $ValType[$tno]="X";
         if( $k==0 || substr($name,$k) eq 'main' ){
            substr($name,0,2)='__main__.';
            $ValPy[$tno]=$name;
            $rc=1 #regular var
         }else{
            substr($name,$k,2)='.';
            $ValPy[$tno]=$name;
            $rc=1 #regular var
         }
      }elsif( length($name) ==1 ){
         $s2=$1;
         if( $s2 eq '_' ){
            $ValType[$tno]="X";
            if( $source=~/^(._\s*\[\s*(\d+)\s*\])/  ){
               $ValPy[$tno]='perl_arg_array['.$2.']';
               $cut=length($1);
            }else{
               $ValPy[$tno]='default_var';
               $cut=2;
            }
         }elsif( $s2 eq 'a' || $s2 eq 'b' ){
            $ValType[$tno]="X";
            $ValPy[$tno]='perl_sort_'.$s2;
            $cut=2;
         }else{
            $rc=1 #regular var
         }
      }else{
        # this is a "regular" name with the length greater then one
        # $cut points to the next symbol after the scanned part of the scapar
           # check for Perl system variables
           if( $1 eq 'ENV'  ){
              $ValType[$tno]="X";
              $ValPy[$tno]='os.environ';
           }elsif( $1 eq 'ARGV'  ){
              $ValType[$tno]="X";
              $ValPy[$tno]='sys.argv';
           }else{
             $rc=1; # regular variable
           }
      }
   }
   return $rc;
}

sub is_regex
# is_regex -- Detemine if this is regex and if yes what are modifers (extract them from $source and encode in Python re.compline faschion
# the dsicvered situation is determinged by length of the return
#if there is modier then return modifier tranlated in re.complile notation (the string length is more then one)
#if this is regex but there is no modifier return 'r'
#if this is string and there is no modifier return '';
{
my $myregex=$_[0];
my (@temp,$sym,$prev_sym,$i,$modifier,$meta_no);
   $modifier='r';
   if( $source=~/^(\w+)/ ){
     $source=substr($source,length($1)); # cut modifier
     $modifier='';
     @temp=split(//,$1);
      for( $i=0; $i<@temp; $i++ ){
         $modifier.=',re.'.uc($temp[$i]);
     }#for
     $regex=1;
     $cut=0;
   }
   @temp=split(//,$myregex);
   $prev_sym='';
   $meta_no=0;
   for( $i=0; $i<@temp; $i++ ){
      $sym=$temp[$i];
      if( $prev_sym ne '\\' && $sym eq '(' ){
         return($modifier,1);
      }elsif( $prev_sym ne '\\' && index('.*+()[]?^$|',$sym)>=-1 ){
        $meta_no++;
      }elsif(  $prev_sym eq '\\' && lc($sym)=~/[bsdwSDW]/){
         $meta_no++;
      }
      $prev_sym=$sym;
   }#for
   $cut=0;
   if( $meta_no>0 ){
      #regular expression without groups
      return ('r', 0);
   }
   return('',0);
}
# Parse regex in case the opeartion is search
# ATTEMTION: this sub modifies $source curring regex modifier from it.
# At the point of invocation the regex is removed from $source (it is passed as the first parameter) so that modifier can be analysed
# if(/regex/) -- .re.match(default_var, r'regex')
# if( $line=~/regex/ )
# ($head,$tail)=split(/s/,$line)
# used from '/', 'm' and 'qr'
sub perl_match
{
my $myregex=$_[0];

my  ($modifier, $i,$sym,$prev_sym,@temp);
my  $is_regex=0;
my  $groups_are_present;
#
# Is this regex or a reguar string used in regex for search
#
   ($modifier,$groups_are_present)=is_regex($myregex);
   if( length($modifier) > 1 ){
      #regex with modifiers
      $quoted_regex='re.compile('.put_regex_in_quotes($myregex).$modifier.')';
   }else{
      # No modifier
      $quoted_regex=put_regex_in_quotes($myregex);
   }
   if( length($modifier)>0 ){
      #this is regex
      if( $tno>=1 && $ValClass[$tno-1] eq '~' ){
         # explisit or implisit '~m' can't be at position 0; you need the left part
         if( $groups_are_present ){
            return '(default_match:=re.match('.$quoted_regex.','; #  we need to have the result of match to extract groups.
         }else{
           return 're.match('.$quoted_regex.','; #  we do not need the result of match as no groups is present.
         }
      }elsif( $ValClass[$tno-1] eq '0'  ||  $ValClass[$tno-1] eq '(' ){
            # this is calse like || /text/ or while(/#/)
            if( $groups_are_present ){
                return '(default_match:=re.match('.$quoted_regex.',default_var))'; #  we need to have the result of match to extract groups.
         }else{
           return 're.match('.$quoted_regex.',default_var)'; #  we do not need the result of match as no groups is present.
         }
      }else{
         return 're.match('.$quoted_regex.',default_var)'; #  we do not need the result of match as no groups is present.
      }
   }else{
      # this is a string
      $ValClass[$tno]="'";
      return '.find('.escape_quotes($myregex).')';
   }

} # perl_match
#
# Remove the last item from stack
#
sub popup
{
    pop(@ValClass);
    pop(@ValPerl);
    pop(@ValPy);
    pop(@ValCom);
}
sub single_quoted_literal
# ATTENTION: returns position after closing bracket
# A backslash represents a backslash unless followed by the delimiter or another backslash,
# in which case the delimiter or backslash is interpolated.
{
($closing_delim,$offset)=@_;
my ($m,$sym);
# The problem is decomposting single quotes string is that for brackets closing delimiter is different from opening
# The second problem is that \n in single quoted string in Perl means two symbols and in Python a single symbol (newline)
      if(index('{[(<',$closing_delim)>-1){
         $closing_delim=~tr/{[(</}])>/;
      }
      # only backlashes are allowed
      for($m=$offset; $m<=length($source); $m++ ){
         $sym=substr($source,$m,1);
         last if( $sym eq $closing_delim && substr($source,$m-1,1) ne '\\' );
      }
      return $m+1; # this is first symbol after closing quote
}#sub single_quoted_literal

#::double_quoted_literal -- decompile double quted literal
# parcial implementation; full implementation requires two pass scheme
# Returns cut
# As a side efecct populates $ValPerl[$tno] $ValPy[$tno]
#
sub double_quoted_literal
{
($closing_delim,$offset)=@_;
my ($k,$quote,$close_pos,$ind,$result,$prefix);
   if( $closing_delim=~tr/{[>// ){
      $closing_delim=~tr/{[(</}])>/;
   }
   $close_pos=single_quoted_literal($closing_delim,$offset); # first position after quote
   $quote=substr($source,$offset,$close_pos-1-$offset); # extract literal
   if (length($quote) == 1 ){
      $ValPy[$tno]=escape_quotes($quote,2);
      return $close_pos;
   }
   $ValPerl[$tno]=$quote; # also will serve as original
   #
   # decompose all scalar variables, if any, Array and hashes are left "as is"
   #
   $k=index($quote,'$');
   if( $k==-1 ){
      # case when double quotes are used for a simple literal that does not reaure interpolation
      # Python equvalence between single and doble quotes alows some flexibility
      $ValPy[$tno]=escape_quotes($quote,2); # always generate with quotes --same for Python 2 and 3
      return $close_pos;
   }
   #
   #decode each part. Double quote literals in Perl are ver difficult to decode
   # This is a parcial implementation of the most common cases
   # Full implementation is possible only in two pass scheme
my  $outer_delim;
    if (index($quote,'"')==-1){
       $outer_delim='"'
    }elsif(index($quote,"'")==-1){
      $outer_delim="'";
    }else{
      $out_delim='"""';
    }
   $result=( $::PyV==3 ) ? "f$outer_delim" : ''; #For python 3 we need special opening quote
   while( $k > -1  ){
      if( $k > 0 ){
         if( substr($quote,$k-1,1) eq '\\' ){
            # escaped $
            $k=index($quote,'$',$k+1);
            next;
         }else{
            # we have the first literal string  before varible
            $result.=escape_quotes(substr($quote,0,$k),$::PyV); # with or without quotes depending on version.
            $result.=' + ' if $::PyV==2; # add literal part of the string
         }
      }
      $result.='{' if( $::PyV==3 );  # we always need '{' for f-strings
      $quote=substr($quote,$k);
      decode_scalar($quote,0); #get's us scalar or system var
      #does not matter what type of veriable this is: regular or special variable
      $result.=$ValPy[$tno]; # copy string determined by decode_scalar. It might changed if Perl contained :: like in $::PyV
      $quote=substr($quote,$cut); # cure the nesserary number of symbol determined by decode_scalar.
      if( $quote=~/^\s*([\[\{].+?[\]\}])/  ){
         #HACK element of the array of hash. Here we cut corners and do not process expressions as index.
         $ind=$1;
         $cut=length($ind);
         $ind =~ tr/$//d;
         $ind =~ tr/{}/[]/;
         $result.=$ind; # add string Variable part of the string
         $quote=substr($quote,$cut);
      }

      if( $::PyV==3 ){
         $result.='}'; # end of variable
      }elsif( length($quote)>0 ){
          $result.=' + '; # for Python2  we add + only if there is at least one more chunk
      }
      $k=index($quote,'$'); #next scalar
   }
   if( length($quote)>0  ){
       #the last part
       $result.=$quote;
   }
   $result.=( $::PyV==3 ) ? $outer_delim : '';
   $ValPy[$tno]=$result;
   return $close_pos;
}
#
# Aug 20, 2020 -- we wilol use the hack -- if there are quotes in the string we will anclose it introple quotes.
#
sub escape_quotes
{
my $string=$_[0];
my $ver=$_[1];
my $quote=
my $result;

   if( $ver==2 ){
      return qq(').$string.qq(') if(index($string,"'")==-1 ); # no need to escape any quotes.
      return q(").$string.qq(") if( index($string,'"')==-1 ); # no need to scape any quotes.
   }else{
      return $string if( index($string,'"')==-1 ); # no need to scape any quotes.
   }
#
# We need to escape quotes
#
   return qq(""").$string.qq(""");
}
sub put_regex_in_quotes
{
my $string=$_[0];
my $ver=$_[1];
my $quote=
my $result;

   return qq(r').$string.qq(') if(index($string,"'")==-1 ); # no need to escape any quotes.
   return q(r").$string.qq(") if( index($string,'"')==-1 ); # no need to scape any quotes.

#
# We are forced to use triple quotes
#
   return qq(r""").$string.qq(""");
   return $result;
}
sub escape_backslash
# All special symbols different from the delimiter and \ should be escaped when translating Perl single quoted literal to Python
# For example \n \t \r  are not treated as special symbols in single quotes in Perl (which is probably a mistake)
{
my $string=$_[0];
my $backslash='\\';
my $result=$string;
   for( my $i=length($string)-1; $i>=0; $i--  ){
      if( substr($string,$i,1) eq $backslash ){
         if(index('nrtfbvae',substr($string,$i+1,1))>-1 ){
            substr($result,$i,0)='\\'; # this is a really crazy nuance
         }
      }
   } # for
   return $result;
}
#
# Typically used without arguments as it openates on PythonCode array
# NOTE: Can have one or more argument and in this case each of the members of the list  will be passed to output_line.
sub gen_statement
{
my $i;
my $line='';
   if (scalar(@_)==0 && scalar(@PythonCode)==0){
      Pythonizer::correct_nest(); # equalize CurNest and NextNest;
      return; # nothing to do
   }
   if( scalar(@_)>0  ){
      #direct print of the statement. Added Aug 10, 2020 --NNB
      for($i=0; $i<@_;$i++ ){
         Pythonizer::output_line($_[$i]);
      }
   }elsif( $::TrStatus<0 && scalar(@ValPy)>0  ){
      $line=$ValPy[0];
      for( $i=1; $i<@ValPy; $i++ ){
         next unless(defined($ValPy[$i]));
         next if( $ValPy[$i] eq '' );
         $s=substr($ValPy[$i],0,1);
         if( $ValPy[$i-1]=~/\w$/ ){
            if( index(q('"/),$s)>-1 || $s=~/\w/ ){
                # print "something" if /abc/
                $line.=' '.$ValPy[$i];
            }else{
                $line.=$ValPy[$i];
            }
         }else{
            $line.=$ValPy[$i];
         }
      }
      ($line) && Pythonizer::output_line($line,' #FAILTRAN');
   }elsif( scalar(@PythonCode)>0 ){
      $line=$PythonCode[0];
      for( my $i=1; $i<@PythonCode; $i++  ){
         next unless(defined($PythonCode[$i]));
         next if( $PythonCode[$i] eq '');
         $s=substr($PythonCode[$i],0,1); # the first symbol
         if( substr($line,-1,1)=~/[\w'"]/ &&  $s =~/[\w'"]/  ){
            # space between identifiers and before quotes
            $line.=' '.$PythonCode[$i];
         }else{
            #no space befor delimiter
            $line.=$PythonCode[$i];
         }
      } # for
      if( defined[$ValCom[-1]] && length($ValCom[-1]) > 1  ){
         # single symbol ValCom will be used as additional determinator of the token in pass 0 -- Sept 18, 200 -- NNB
         #that means that you need a new line. bezroun Feb 3, 2020
         Pythonizer::output_line($line,$ValCom[-1] );
      }else{
        Pythonizer::output_line($line);
      }
      for ($i=1; $i<$#ValCom; $i++ ){
          if( defined($ValCom[$i]) && length($ValCom[$i])>1  ){
             # NOTE: This is done because comment can be in a wrong position due to Python during generation and the correct placement  is problemtic
             Pythonizer::output_line('',$ValCom[$i] );
          }  # if defined
      }
   }elsif( $line ){
       Pythonizer::output_line('','#NOTRANS: '.$line);
   }
   if( $::TrStatus < 0  && $::debug ){
      out("\nTokens: $TokenStr ValPy: ".join(' '.@PythonCode));
   }
#
# Prepare for the next line generation
#
   Pythonizer::correct_nest(); # equalize CurNest and NextNest;
   @PythonCode=(); # initialize for the new line
   return;
}
#
# Add generated chunk or multile chaunks of Python code checking for overflow
#
sub gen_chunk
{
my $i;
#
# Put generated chunk into array.
#
   for($i=0; $i<@_;$i++ ){
      if( scalar(@PythonCode) >256  ){
         logme('S',"Number of generated chunks for the line exceeded 256");
         sleep 5;
         if( $::debug > 0  ){
            $DB::single = 1;
         }
      }
      push(@PythonCode,$_[$i]);
   } #for
   ($::debug>4) && say 'Generated parcial line ',join('',@PythonCode);
}
1;
