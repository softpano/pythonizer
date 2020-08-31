## Pythonizer: "fuzzy" translator/transformer from Perl to Python 
### THIS IS AN ANNOUNCEMENT FOR ALPHA VERSION 0.5

Aug 31, 2020: Version 0.5 was uploaded. Regular expression and tr function translation was  improved. Many other changes and  error corrections. -r (refactor) option implemented to allow refactoring  Perl source via pre-pythonlizer.pl in integrated fashion. 

Aug 22, 2020: Version 0.4 was uploaded. The walrus operator and the f-strings now are used to tranlate Perl double quoted literals if option -p iset to 3 (default is -p=3). In this case Python 3.8 is used as the target language) 

Aug 17, 2020: Version 0.3 was uploaded. Changes since version 0.2: default version of Python used is now version 3.8; option -p allows to set version 2 if you still need generation for Python 2.7 (more constructs will be untranslatable).  See user guide for details. 

This readme is for informational purposes only and is not intended to be updated often. More current information can be found at:  

http://www.softpanorama.org/Scripting/Pythonorama/Python_for_perl_programmers/Pythonizer/index.shtml

http://www.softpanorama.org/Scripting/Pythonorama/Python_for_perl_programmers/Pythonizer/user_guide.shtml


Please note that this is an alpha version, not beta (traditionally beta are versions are 0.9 - 0.999). So major changes and enhancements are possible. At the present state phase, it still does not even attampt to tranlate construct outside subset typycally used in sysadmin scripts. There is also pre-pythonizer -- the first phaze of translation which currentlyis optionsl, although running Perl script via it increases chances that the script will be transliterated with fewer errors. 

HISTORY: 

Aug 31, 2020: Version 0.5 was uploaded

Aug 22, 2020: Version 0.4 was uploaded

Aug 17, 2020: Version 0.3 was uploaded 

Aug 05, 2020: Version 0.2 was uploaded. 

Here is an fragment of translation of pre-pythonizer.pl which exists in this repositorory. It demostrates how thecurrent version if pythonizer performs:  
    

#### Example of tranlsation (version 0.2 alpha, Aug 12, 2020) 

```Perl
   PYTHONIZER: Fuzzy translator of Python to Perl. Version 0.50 (last modified 200831_0011) Running at 20/08/31 09:11
Logs are at /tmp/Pythonizer/pythonizer.200831_0911.log. Type -h for help.

================================================================================


Results of transcription are written to the file  pre_pythonizer.py
==========================================================================================
... ... ...
  54 | 0 |      |#$debug=3; # starting from Debug=3 only the first chunk processed
  55 | 0 |      |STOP_STRING='' # In debug mode gives you an ability to switch trace on any type of error message for example S (via hook in logme).
                                                                                                  #PL:    $STOP_STRING='';
  56 | 0 |      |use_git_repo=''                                                                  #PL: $use_git_repo='';
  57 | 0 |      |
  58 | 0 |      |# You can switch on tracing from particular line of source ( -1 to disable)
  59 | 0 |      |breakpoint=-1                                                                    #PL: $breakpoint=-1;
  60 | 0 |      |SCRIPT_NAME=__file__[__file__.rfind('/')+1:]                                     #PL: $SCRIPT_NAME=substr($0,rindex($0,'/')+1);
  61 | 0 |      |if (dotpos:=SCRIPT_NAME.find('.'))>-1:                                           #PL: if( ($dotpos=index($SCRIPT_NAME,'.'))>-1 ) {
  62 | 1 |      |   SCRIPT_NAME=SCRIPT_NAME[0:dotpos]                                             #PL: $SCRIPT_NAME=substr($SCRIPT_NAME,0,$dotpos);
  64 | 0 |      |
  65 | 0 |      |OS=os.name # $^O is built-in Perl variable that contains OS name
                                                                                                  #PL:    $OS=$^O;
  66 | 0 |      |if OS=='cygwin':                                                                 #PL: if($OS eq 'cygwin' ){
  67 | 1 |      |   HOME='/cygdrive/f/_Scripts'    # $HOME/Archive is used for backups
                                                                                                  #PL:       $HOME="/cygdrive/f/_Scripts";
  68 | 0 |      |elif OS=='linux':                                                                #PL: elsif($OS eq 'linux' ){
  69 | 1 |      |   HOME=os.environ['HOME']    # $HOME/Archive is used for backups
                                                                                                  #PL:       $HOME=$ENV{'HOME'};
  71 | 0 |      |LOG_DIR=f"/tmp/{SCRIPT_NAME}"                                                    #PL: $LOG_DIR="/tmp/$SCRIPT_NAME";
  72 | 0 |      |FormattedMain=('sub main\n','{\n')                                               #PL: @FormattedMain=("sub main\n","{\n");
  73 | 0 |      |FormattedSource=FormattedSub.copy                                                #PL: @FormattedSource=@FormattedSub=@FormattedData=();
  74 | 0 |      |mainlineno=len(FormattedMain) # we need to reserve one line for sub main
                                                                                                  #PL:    $mainlineno=scalar( @FormattedMain);
  75 | 0 |      |sourcelineno=sublineno=datalineno=0                                              #PL: $sourcelineno=$sublineno=$datalineno=0;
  76 | 0 |      |
  77 | 0 |      |tab=4                                                                            #PL: $tab=4;
  78 | 0 |      |nest_corrections=0                                                               #PL: $nest_corrections=0;
  79 | 0 |      |keyword={'if': 1,'while': 1,'unless': 1,'until': 1,'for': 1,'foreach': 1,'given': 1,'when': 1,'default': 1}
                                                                                                  #PL: %keyword=('if'=>1,'while'=>1,'unless'=>1, 'until'=>1,'for'=>1,'foreach'=>1,'give
                                                                                                  Cont:  n'=>1,'when'=>1,'default'=>1);
  80 | 0 |      |
  81 | 0 |      |logme(['D',1,2]) # E and S to console, everything to the log.
                                                                                                  #PL:    logme('D',1,2);
  82 | 0 |      |banner([LOG_DIR,SCRIPT_NAME,'PREPYTHONIZER: Phase 1 of pythonizer',30]) # Opens SYSLOG and print STDERRs banner; parameter 4 is log retention period
                                                                                                  #PL:    banner($LOG_DIR,$SCRIPT_NAME,'PREPYTHONIZER: Phase 1 of pythonizer',30);
  83 | 0 |      |get_params() # At this point debug  flag can be reset
                                                                                                  #PL:    get_params();
  84 | 0 |      |if debug>0:                                                                      #PL: if( $debug>0 ){
  85 | 1 |      |   logme(['D',2,2])    # Max verbosity
                                                                                                  #PL:       logme('D',2,2);
  86 | 1 |      |   print(f"ATTENTION!!! {SCRIPT_NAME} is working in debugging mode {debug} with autocommit of source to {HOME}/Archive\n",file=sys.stderr,end="")
                                                                                                  #PL: print STDERR "ATTENTION!!! $SCRIPT_NAME is working in debugging mode $debug with
                                                                                                  Cont:   autocommit of source to $HOME/Archive\n";
  87 | 1 |      |   autocommit([f"{HOME}/Archive",use_git_repo])    # commit source archive directory (which can be controlled by GIT)
                                                                                                  #PL:       autocommit("$HOME/Archive",$use_git_repo);
  89 | 0 |      |print(f"Log is written to {LOG_DIR}, The original file will be saved as {fname}.original unless this file already exists ")
                                                                                                  #PL: say "Log is written to $LOG_DIR, The original file will be saved as $fname.origi
                                                                                                  Cont:  nal unless this file already exists ";
  90 | 0 |      |print('=' * 80,'\n',file=sys.stderr)                                             #PL: say STDERR  "=" x 80,"\n";
  91 | 0 |      |
  92 | 0 |      |#
  93 | 0 |      |# Main loop initialization variables
  94 | 0 |      |#
  95 | 0 |      |new_nest=cur_nest=0                                                              #PL: $new_nest=$cur_nest=0;
  96 | 0 |      |#$top=0; $stack[$top]='';
  97 | 0 |      |lineno=noformat=SubsNo=0                                                         #PL: $lineno=$noformat=$SubsNo=0;
  98 | 0 |      |here_delim='\n' # impossible combination
                                                                                                  #PL:    $here_delim="\n";
  99 | 0 |      |InfoTags=''                                                                      #PL: $InfoTags='';
 100 | 0 |      |SourceText=sys.stdin.readlines().copy                                            #PL: @SourceText=;
 101 | 0 |      |
 102 | 0 |      |#
 103 | 0 |      |# Slurp the initial comment block and use statements
 104 | 0 |      |#
 105 | 0 |      |ChannelNo=lineno=0                                                               #PL: $ChannelNo=$lineno=0;
 106 | 0 |      |while 1:                                                                         #PL: while(1){
 107 | 1 |      |   if lineno==breakpoint:                                                        #PL: if( $lineno == $breakpoint ){
 109 | 2 |      |      pdb.set_trace()                                                            #PL: }
 110 | 1 |      |   line=line.rstrip("\n")                                                        #PL: chomp($line=$SourceText[$lineno]);
 111 | 1 |      |   if re.match(r'^\s*$',line):                                                   #PL: if( $line=~/^\s*$/ ){
 112 | 2 |      |      process_line(['\n',-1000])                                                 #PL: process_line("\n",-1000);
 113 | 2 |      |      lineno+=1                                                                  #PL: $lineno++;
 114 | 2 |      |      continue                                                                   #PL: next;
 116 | 1 |      |   intact_line=line                                                              #PL: $intact_line=$line;
 117 | 1 |      |   if intact_line[0:1]=='#':                                                     #PL: if( substr($intact_line,0,1) eq '#' ){
 118 | 2 |      |      process_line([line,-1000])                                                 #PL: process_line($line,-1000);
 119 | 2 |      |      lineno+=1                                                                  #PL: $lineno++;
 120 | 2 |      |      continue                                                                   #PL: next;
 122 | 1 |      |   line=normalize_line(line)                                                     #PL: $line=normalize_line($line);
 123 | 1 |      |   line=line.rstrip("\n")                                                        #PL: chomp($line);
 124 | 1 |      |   (line)=line.split(' '),1                                                      #PL: ($line)=split(' ',$line,1);
 125 | 1 |      |   if re.match(r'^use\s+',line):                                                 #PL: if($line=~/^use\s+/){
 126 | 2 |      |      process_line([line,-1000])                                                 #PL: process_line($line,-1000);
 127 | 1 |      |   else:                                                                         #PL: else{
 128 | 2 |      |      break                                                                      #PL: last;
 130 | 1 |      |   lineno+=1                                                                     #PL: $lineno++;
 131 | 0 |      |#while
  ... ... ...
```
