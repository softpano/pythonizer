## Two-pass "fuzzy" transformer from Perl to "semi-Python" 
### THIS IS AN ANNOUNCEMENT FOR ALPHA VERSION 0.2 

This readme is for informational purposes only and is not intended to be updated often. More current information can be found at:  

http://www.softpanorama.org/Scripting/Pythonorama/Python_for_perl_programmers/Pythonizer/index.shtml

http://www.softpanorama.org/Scripting/Pythonorama/Python_for_perl_programmers/Pythonizer/user_guide.shtml

Some organizations are now involved in converting their Perl codebase into Python. The author previously participated in several projects of converting mainframe codebase to Unix (mainly AIX) and thinks that this area might be a useful expansion of his skills. 
 
Of course, Perl 5 is here to stay (please note what happened with people who were predicting the demise of Fortran ;-), but for some reason, 
several organizations are expressed interest in converting their support script codebase into a single language. Most often, this is Python. 
Ruby, which is probably a better match for such a translation, is seldom used. 

My feeling is that there should be some better tools for this particular task to lessen the costs, time, and effort. One trivial idea is to have a better, written with some level of knowledge of compiler technologies tool that falls into the category of "small toy language compliers" with the total effort around one man-year or less. 

Assuming ten lines per day of debugged code for the task of complexity comparable with the writing of compilers, the estimated size should be around 3-5K lines of code (~1K line phase 1 and 2-3K line phase 2 

So far, this just an idea, although the prototype was already written. The idea might be wrong, and it might be impossible to write anything useful in less than 3K lines. As of August 2020, around 2K codelines were written, and alpha version works more or less OK on simple Perl scripts with around 80% statement translation success rate.

As the test, I  had chosen pre_pythonizer.pl -- the script that converts Perl script into the form more suitable to processing (optional). The run of pythonizer on this script serves as a kind of the acceptance test, which allows us to detect when the codebase reaches the stage of the alpha version.  Of course, this script uses a very small subset of Perl (no OO, no modules). Still, in a way it is representative of a large category of Perl script written by system administrators, who rarely use esoteric Perl features (using Perl mostly as "better Bash") and, generally, coming from C+shell background, most of them, especially older folk, prefer the procedural style of programming. Only GUI programs are written using OO-style by this category of programmers. Sometimes Web tools too. 

For this category of scripts, the automatic translation (or more correctly transliteration ;-) can provide considerable labor savings during conversion, allowing to accomplish the task in less time and with higher quality. Essentially you can start to debug and enhance the converted script on the same day. Of course,  when Perl functions and regex are used extensively, the result can be simply incorrect. And Perl has enough idiosyncrasies that prevent even transliteration, to say nothing about translation. One interesting lesson from writing alpha version is that while Perl superficially has a decently designed lexical level (at least in comparison with BASH ;-) , the devil is in details and lexical scanner for Perl is a very complex undertaking that too probably the half of time spent on the project and slowed it considerably.  Also, the idea that Python is simple, orthogonal language proved to be false. In some areas, it is more convoluted than Perl and has more ways to accomplish the same task (which unfortunately often differ between 2,7 and 3,8(   

Please note that what was uploaded in August 2020 is version 0.2. It is alpha, not beta (traditionally beta are versions are 0.9 - 0.999). So major changes and enhancements are possible. At the present state phase, it is not used at all, although running Perl script via it increases chances that it will be transliterated with fewer errors. 

But even in the current form, this program may provide some savings in translation effort. Of course, some Python functions do not match 1:1 Perl functions, and you need to look at the translation with a grain of salt,  but that's probably unavoidable. It does not make the transliterated text useless.  Also, absence of goto, "until" loop, double quotes literals (until Python 3.6) as well as an ability to use assignment in conditional statements (until Python 3.8) complicated the task further. But simple statements can be translated more or less OK (see below.)  

Some missing features can be emulated: right now, double-quoted literals are decompiled and then translated to a sequence of concatenation (see below). In Python 3.8+, they can be compiled into F-strings. Assignment in if statement now is implemented in Python 3.8, so you do not need to refactor the code and push assignment out of conditionals anymore. 

NOTE: As of Aug 5,2020, the alpha version 0.2 was uploaded. 

Here is an example of translation of an older verion (0.007) which is stll relevant and demostrates how this tranliterator works: 
    

#### Example of tranlsation (version 0.07 alpha, Nov 20, 2019) 

```Perl
PYTHONIZER: Fuzzy translator of Python to Perl (last modified 191120_1730) Running at 19/11/20 17:30
Logs are at /tmp/Pythonizer/pythonizer.191120_1730.log. Type -h for help.

================================================================================


Results of transcription are written to the file  Mytests/main_test.py
... ... ...
  59 | 0 |      |breakpoint=-1                                                            #Perl: $breakpoint=-1;
  60 | 0 |      |SCRIPT_NAME=sys.argv[0][sys.argv[0].rfind( '/')+1:]                      #Perl: $SCRIPT_NAME=substr($0,rindex($0,'/')+1);
  61 | 0 |      |dotpos=SCRIPT_NAME.find( '.')                                            #Perl: if( ($dotpos=index($SCRIPT_NAME,'.'))>-1 ) {
  61 | 0 |      |if dotpos>-1:
  62 | 1 |      |   SCRIPT_NAME=SCRIPT_NAME[0:dotpos]                                     #Perl: $SCRIPT_NAME=substr($SCRIPT_NAME,0,$dotpos);
  64 | 0 |      |
  65 | 0 |      |OS=os.name # $^O is built-in Perl variable that contains OS name         #Perl: $OS=$^O;
  66 | 0 |      |if OS== 'cygwin':                                                        #Perl: if($OS eq 'cygwin' ){
  67 | 1 |      |   HOME= "/cygdrive/f/_Scripts" # $HOME/Archive is used for backups      #Perl: $HOME="/cygdrive/f/_Scripts";
  68 | 0 |      |elif OS== 'linux':                                                       #Perl: }elsif($OS eq 'linux' ){
  69 | 1 |      |   HOME=ENV[ 'HOME'] # $HOME/Archive is used for backups                 #Perl: $HOME=ENV{'HOME'};
  71 | 0 |      |LOG_DIR= "/tmp/" + SCRIPT_NAME                                           #Perl: $LOG_DIR="/tmp/$SCRIPT_NAME";
  72 | 0 |      |
  73 | 0 |      |
  74 | 0 |      |tab=3                                                                    #Perl: $tab=3;
  75 | 0 |      |nest_corrections=0                                                       #Perl: $nest_corrections=0;
  76 | 0 |      |keyword={ 'if': 1, 'while': 1, 'unless': 1, 'until': 1, 'for': 1, 'foreach': 1, 'given': 1, 'when': 1, 'default': 1}
                                                                                          #Perl: %keyword=('if'=>1,'while'=>1,'unless'=>1, 'until'=>1,'for'=>1,'foreach'=
                                                                                          #Cont: >1,'given'=>1,'when'=>1,'default'=>1);
  77 | 0 |      |
  78 | 0 |      |logme([ 'D',1,2)]) # E and S to console, everything to the log.          #Perl: logme('D',1,2);
  79 | 0 |      |banner([LOG_DIR,SCRIPT_NAME, 'Phase 1 of pythonizer',30)]) # Opens SYSLOG and print STDERRs banner; parameter 4 is log retention period #Perl: banner($LOG_DIR,$SCRIPT_NAME,'Phase 1 of pythonizer',30);
  80 | 0 |      |get_params([)]) # At this point debug  flag can be reset                 #Perl: get_params();
  81 | 0 |      |if debug>0:                                                              #Perl: if( $debug>0 ){
  82 | 1 |      |   logme([ 'D',2,2)]) # Max verbosity                                    #Perl: logme('D',2,2);
  83 | 1 |      |   print >>sys.stderr "ATTENTION!!! " + SCRIPT_NAME + " is working in debugging mode " + debug + " with autocommit of source to " + HOME + "/Archive\n"
                                                                                          #Perl: print STDERR "ATTENTION!!! $SCRIPT_NAME is working in debugging mode $de
                                                                                          #Cont: bug with autocommit of source to $HOME/Archive\n";
  84 | 1 |      |   autocommit([HOME + "/Archive",use_git_repo)]) # commit source archive directory (which can be controlled by GIT) #Perl: autocommit("$HOME/Archive",$use_git_repo);
  86 | 0 |      |print >>sys.stderr "=" * 80, "\n\n"                                      #Perl: print STDERR  "=" x 80,"\n\n";
... ... ...
 100 | 0 |      |#
 101 | 0 |      |# MAIN LOOP
 102 | 0 |      |#
 103 | 0 |      |for lineno range(0,SourceText):                                          #Perl: for( $lineno=0; $lineno<@SourceText; $lineno++  ){
 104 | 1 |      |   line=SourceText[lineno]                                               #Perl: $line=$SourceText[$lineno];
 105 | 1 |      |   offset=0                                                              #Perl: $offset=0;
 106 | 1 |      |   line=line.string.rstrip("\n")                                         #Perl: chomp($line);
 107 | 1 |      |   intact_line=line                                                      #Perl: $intact_line=$line;
 108 | 1 |      |   if lineno==breakpoint:                                                #Perl: if( $lineno == $breakpoint ){
 109 | 2 |      |      DB.single=1                                                        #Perl: $DB::single = 1
 111 | 1 |      |   line=line _trantab111=maketrans('\t',' ') # eliminate \t              #Perl: $line=~tr/\t/ /;
 112 | 1 |      |   if line[-1:1]== "\r":                                                 #Perl: if( substr($line,-1,1) eq "\r" ){
 113 | 2 |      |      line=[0:-1]line                                                    #Perl: chop($line);
 115 | 1 |      |   # trip traling blanks, if any
 116 | 1 |      |   if line.re.match(r"(^.*\S)\s+$"):                                     #Perl: if( $line=~/(^.*\S)\s+$/ ){
 117 | 2 |      |      line=rematch.group(1)                                              #Perl: $line=$1;
  ... ... ...
```
