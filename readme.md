## Two-pass "fuzzy" transformer from Perl to "semi-Python" 
### THIS IS A PRE ANNOUNCEMENT 

Some organizations are now involved in converting their Perl codebase into Python. The author previously participated in several projects of converting mainframe codebase to Unix (mainly AIX) and think that this area might be a useful expansion of his skills. 
 
Of course, Perl 5 is here to stay (please note what happened with people who were predicting the demise of Fortran ;-), but for some reason, 
several organizations are expressed interest in converting their support script codebase into a single language. Most often, this is Python. 
Ruby, which is probably a better match for such a translation, is seldom used. 

My feeling is that there should be some better tools for this particular task to lessen the costs, time, and effort. One trivial idea is to have a better, 
whitten with some level of knowledge of compiler technologies tool that falls into the category of medium size complies with total effort around one man year or less. 

Assuming ten lines per day of debugged code for the task of complexity comparable with the writing of compilers, the estimated size should be around 3-4K lines of code. 

So far, just an idea, although the prototype was already written. It might be wrong, and it might be impossible to write anything useful in less than 4K lines. As of November 2019 less then 1.5K lines were written and so far it looks like this estimate is more or less realistic, if we omit extreme idesyncracies.  

In any case the idea of "fuzzy pythonizer" is to translate a subset of Perl typically used in sysadmin scripts into Python, marking untranslatable statements, or statements parts with appropriate comments using a combination of two approaches approaches

For more info see 

http://www.softpanorama.org/Scripting/Pythonorama/Python_for_perl_programmers/two_pass_fuzzy_compiler_from_perl_to_python.shtml

As of Nov 20 alpha version produced the following tranlation of pre_pythoner.pl 

```Perl
PYTHONIZER: Fuzzy translator of Python to Perl (last modified 191120_1730) Running at 19/11/20 17:30
Logs are at /tmp/Pythonizer/pythonizer.191120_1730.log. Type -h for help.

================================================================================


Results of transcription are written to the file  Mytests/main_test.py
... ... ... 
  58 | 0 |      |# You can switch on tracing from particular line of source ( -1 to disable)
  59 | 0 |      |breakpoint=-1                                                            #Perl: $breakpoint=-1;
  60 | 0 |      |SCRIPT_NAME=sys.argv[0][sys.argv[0].rfind( '/')+1:]                      #Perl: $SCRIPT_NAME=substr($0,rindex($0,'/')+1);
  61 | 0 |      |dotpos=SCRIPT_NAME.find( '.')                                            #Perl: if( ($dotpos=index($SCRIPT_NAME,'.'))>-1 ) {
  61 | 0 |      |if dotpos>-1:                                                            #Perl: if( ($dotpos=index($SCRIPT_NAME,'.'))>-1 ) {
  62 | 1 |      |   SCRIPT_NAME=SCRIPT_NAME[:dotpos]                                      #Perl: $SCRIPT_NAME=substr($SCRIPT_NAME,0,$dotpos);
  64 | 0 |      |
  65 | 0 | FAIL |$OS=$^O; # $^O is built-in Perl variable that contains OS name
  66 | 0 |      |if OS== 'cygwin':                                                        #Perl: if($OS eq 'cygwin' ){
  67 | 1 |      |   $HOME="/cygdrive/f/_Scripts";  # $HOME/Archive is used for backups
  68 | 0 |      |elif OS== 'linux'):                                                      #Perl: }elsif($OS eq 'linux' ){
  69 | 1 |      |   $HOME=ENV{'HOME'}; # $HOME/Archive is used for backups
  71 | 0 |      |LOG_DIR= "/tmp/" + SCRIPT_NAME                                           #Perl: $LOG_DIR="/tmp/$SCRIPT_NAME";
  72 | 0 |      |
  73 | 0 |      |
  74 | 0 |      |tab=3                                                                    #Perl: $tab=3;
  75 | 0 |      |nest_corrections=0                                                        #Perl: $nest_corrections=0;
  76 | 0 |      |keyword={ 'if': 1, 'while': 1, 'unless': 1, 'until': 1, 'for': 1, 'foreach': 1, 'given': 1, 'when': 1, 'default': 1}
                                                                         #Perl: %keyword=('if'=>1,'while'=>1,'unless'=>1, 'until'=>1,'for'=>1,'foreach'=>1,'given'=>1,'when'=>1,'default'=>1);
  77 | 0 |      |
  78 | 0 |      |logme('D',1,2); # E and S to console, everything to the log.
  79 | 0 |      |banner($LOG_DIR,$SCRIPT_NAME,'Phase 1 of pythonizer',30); # Opens SYSLOG and print STDERRs banner; parameter 4 is log retention period
  80 | 0 |      |get_params(); # At this point debug  flag can be reset
  81 | 0 |      |if debug>0:                                                               #Perl: if( $debug>0 ){
  82 | 1 |      |   logme('D',2,2); # Max verbosity
  83 | 1 |      |   print >>sys.stderr "ATTENTION!!! " + SCRIPT_NAME + " is working in debugging mode " + debug + " with autocommit of source to " + HOME + "/Archive\"
                                                                         #Perl: print STDERR "ATTENTION!!! $SCRIPT_NAME is working in debugging mode $debug with autocommit of source to $HOME/Archive\n";
  84 | 1 |      |   autocommit("$HOME/Archive",$use_git_repo); # commit source archive directory (which can be controlled by GIT)
  86 | 0 |      |print >>sys.stderr "=&quot; * 80                                       #Perl: print STDERR  "=" x 80,"\n";

