## Pythonizer: "fuzzy" translator/transformer from Perl to Python 
### THIS IS AN ANNOUNCEMENT FOR ALPHA VERSION 0.4 

Aug 22,2020: Version 0.4 was uploaded. The walrus operator and the f-strings now are used to tranlate Perl double quoted literals if option -p iset to 3 (default is -p=3). In this case Python 3.8 is used as the target language) 

Aug 17, 2020: Version 0.3 was uploaded. Changes since version 0.2: default version of Python used is now version 3.8; option -p allows to set version 2 if you still need generation for Python 2.7 (more constructs will be untranslatable).  See user guide for details. 

This readme is for informational purposes only and is not intended to be updated often. More current information can be found at:  

http://www.softpanorama.org/Scripting/Pythonorama/Python_for_perl_programmers/Pythonizer/index.shtml

http://www.softpanorama.org/Scripting/Pythonorama/Python_for_perl_programmers/Pythonizer/user_guide.shtml


Please note that this is an alpha version, not beta (traditionally beta are versions are 0.9 - 0.999). So major changes and enhancements are possible. At the present state phase, it still does not even attampt to tranlate construct outside subset typycally used in sysadmin scripts. There is also pre-pythonizer -- the first phaze of translation which currentlyis optionsl, although running Perl script via it increases chances that the script will be transliterated with fewer errors. 

HISTORY: 

Aug 22, 2020: Version 0.4 was uploaded

Aug 17, 2020: Version 0.3 was uploaded 

Aug 05, 2020: Version 0.2 was uploaded. 

Here is an fragment of translation of pre-pythonizer.pl which exists in this repositorory. It demostrates how thecurrent version if pythonizer performs:  
    

#### Example of tranlsation (version 0.2 alpha, Aug 12, 2020) 

```Perl
  58 | 0 |      |breakpoint=-1                                                                    #PL: $breakpoint=-1;
  59 | 0 |      |SCRIPT_NAME=__file__[__file__.rfind('/')+1:]                                     #PL: $SCRIPT_NAME=substr($0,rindex($0,'/')+1);
  60 | 0 |      |dotpos=SCRIPT_NAME.find('.')                                                     #PL: if( ($dotpos=index($SCRIPT_NAME,'.'))>-1 ) {
  60 | 0 |      |if dotpos>-1:                                                                    #PL: if( ($dotpos=index($SCRIPT_NAME,'.'))>-1 ) {
  61 | 1 |      |   SCRIPT_NAME=SCRIPT_NAME[0:dotpos]                                             #PL: $SCRIPT_NAME=substr($SCRIPT_NAME,0,$dotpos);
  63 | 0 |      |
  64 | 0 |      |OS=os.name # $^O is built-in Perl variable that contains OS name
                                                                                                  #PL:    $OS=$^O;
  65 | 0 |      |if OS=='cygwin':                                                                 #PL: if($OS eq 'cygwin' ){
  66 | 1 |      |   HOME="/cygdrive/f/_Scripts"    # $HOME/Archive is used for backups
                                                                                                  #PL:       $HOME="/cygdrive/f/_Scripts";
  67 | 0 |      |elif OS=='linux':                                                                #PL: elsif($OS eq 'linux' ){
  68 | 1 |      |   HOME=os.environ['HOME']    # $HOME/Archive is used for backups
                                                                                                  #PL:       $HOME=$ENV{'HOME'};
  70 | 0 |      |LOG_DIR="/tmp/" + SCRIPT_NAME                                                    #PL: $LOG_DIR="/tmp/$SCRIPT_NAME";
  71 | 0 |      |
  72 | 0 |      |
  73 | 0 |      |tab=3                                                                            #PL: $tab=3;
  74 | 0 |      |nest_corrections=0                                                               #PL: $nest_corrections=0;
  75 | 0 |      |keyword={'if': 1,'while': 1,'unless': 1,'until': 1,'for': 1,'foreach': 1,'given': 1,'when': 1,'default': 1}
                                                                                                  #PL: %keyword=('if'=>1,'while'=>1,'unless'=>1, 'until'=>1,'for'=>1,'foreach'=>1,'give
                                                                                                  Cont:  n'=>1,'when'=>1,'default'=>1);
  76 | 0 |      |
  77 | 0 |      |logme(['D',1,2]) # E and S to console, everything to the log.
                                                                                                  #PL:    logme('D',1,2);
  78 | 0 |      |banner([LOG_DIR,SCRIPT_NAME,'Phase 1 of pythonizer',30]) # Opens SYSLOG and print STDERRs banner; parameter 4 is log retention period
                                                                                                  #PL:    banner($LOG_DIR,$SCRIPT_NAME,'Phase 1 of pythonizer',30);
  79 | 0 |      |get_params() # At this point debug  flag can be reset
                                                                                                  #PL:    get_params();
  80 | 0 |      |if debug>0:                                                                      #PL: if( $debug>0 ){
  81 | 1 |      |   logme(['D',2,2])    # Max verbosity
                                                                                                  #PL:       logme('D',2,2);
  82 | 1 |      |   print >>sys.stderr "ATTENTION!!! " + SCRIPT_NAME + " is working in debugging mode " + debug + " with autocommit of source to " + HOME + "/Archive\n"
                                                                                                  #PL: print STDERR "ATTENTION!!! $SCRIPT_NAME is working in debugging mode $debug with
                                                                                                  Cont:   autocommit of source to $HOME/Archive\n";
  83 | 1 |      |   autocommit([HOME + "/Archive",use_git_repo])    # commit source archive directory (which can be controlled by GIT)
                                                                                                  #PL:       autocommit("$HOME/Archive",$use_git_repo);
  85 | 0 |      |print >>sys.stderr "=" * 80,"\n\n"                                               #PL: print STDERR  "=" x 80,"\n\n";
  86 | 0 |      |
  87 | 0 |      |#
  88 | 0 |      |# Main loop initialization variables
  89 | 0 |      |#
  90 | 0 |      |new_nest=cur_nest=0                                                              #PL: $new_nest=$cur_nest=0;
  91 | 0 |      |#$top=0; $stack[$top]='';
  92 | 0 |      |lineno=0                                                                         #PL: $lineno=0;
  93 | 0 |      |fline=0 # line number in FormattedSource code
                                                                                                  #PL:    $fline=0;
  94 | 0 |      |here_delim="\n" # impossible combination
                                                                                                  #PL:    $here_delim="\n";
  95 | 0 |      |noformat=0                                                                       #PL: $noformat=0;
  96 | 0 |      |SubsNo+=1                                                                        #PL: $SubsNo++;
  97 | 0 |      |InfoTags=''                                                                      #PL: $InfoTags='';
  98 | 0 |      |SourceText=STDIN.read()                                                          #PL: @SourceText=<STDIN>;
  99 | 0 |      |#
 100 | 0 |      |# MAIN LOOP
 101 | 0 |      |#
 102 | 0 |      |for lineno in range(0,len(SourceText)):                                          #PL: for( $lineno=0; $lineno<@SourceText; $lineno++  ){
 103 | 1 |      |   line=SourceText[lineno]                                                       #PL: $line=$SourceText[$lineno];
 104 | 1 |      |   offset=0                                                                      #PL: $offset=0;
 105 | 1 |      |   line=line.rstrip("\n")                                                        #PL: chomp($line);
 106 | 1 |      |   intact_line=line                                                              #PL: $intact_line=$line;
 107 | 1 |      |   if lineno==breakpoint:                                                        #PL: if( $lineno == $breakpoint ){
 109 | 2 |      |      DB.single=1                                                                #PL: }
 110 | 1 |      |   line=line.translate(maketrans('\t',' '))    # eliminate \t
                                                                                                  #PL:       $line=~tr/\t/ /;
 111 | 1 |      |   if line[-1:1]=="\r":                                                          #PL: if( substr($line,-1,1) eq "\r" ){
 112 | 2 |      |      line=line[0:-1]                                                            #PL: chop($line);
 114 | 1 |      |   # trip traling blanks, if any
 115 | 1 |      |   if line.re.match(r"(^.*\S)\s+$"):                                             #PL: if( $line=~/(^.*\S)\s+$/ ){
 116 | 2 |      |      line=rematch.group(1)                                                      #PL: $line=$1;
 118 | 1 |      |
 119 | 1 |      |   #
 120 | 1 |      |   # Check for HERE line
 121 | 1 |      |   #
 122 | 1 |      |
 123 | 1 |      |   if noformat:                                                                  #PL: if($noformat){
 124 | 2 |      |      if line==here_delim:                                                       #PL: if( $line eq $here_delim ){
 125 | 3 |      |         noformat=0                                                              #PL: $noformat=0;
 126 | 3 |      |         InfoTags=''                                                             #PL: $InfoTags='';
 128 | 2 |      |      process_line([line,-1000])                                                 #PL: process_line($line,-1000);
 129 | 2 |      |      continue                                                                   #PL: next;
 131 | 1 |      |
 132 | 1 |      |   if line.re.match(r"<<['\"](\w+)['\"]$"):                                      #PL: if( $line =~/<<['"](\w+)['"]$/ ){
 133 | 2 |      |      here_delim=rematch.group(1)                                                #PL: $here_delim=$1;
 134 | 2 |      |      noformat=1                                                                 #PL: $noformat=1;
 135 | 2 |      |      InfoTags='HERE'                                                            #PL: $InfoTags='HERE';
 137 | 1 |      |   #
 138 | 1 |      |   # check for comment lines
 139 | 1 |      |   #
 140 | 1 |      |   if line[0:1]=='#':                                                            #PL: if( substr($line,0,1) eq '#' ){
 141 | 2 |      |      if line=='#%OFF':                                                          #PL: if( $line eq '#%OFF' ){
 142 | 3 |      |         noformat=1                                                              #PL: $noformat=1;
 143 | 3 |      |         here_delim='#%ON'                                                       #PL: $here_delim='#%ON';
 144 | 3 |      |         InfoTags='OFF'                                                          #PL: $InfoTags='OFF';
 145 | 2 |      |      elif line.re.match(r"^#%ON"):                                              #PL: elsif( $line =~ /^#%ON/ ){
 146 | 3 |      |         noformat=0                                                              #PL: $noformat=0;
 147 | 2 |      |      elif line[0:6]=='#%NEST':                                                  #PL: elsif( substr($line,0,6) eq '#%NEST') {
 148 | 3 |      |         if line.re.match(r"^#%NEST=(\d+)"):                                     #PL: if( $line =~ /^#%NEST=(\d+)/) {
 149 | 4 |      |            if cur_nest!=rematch.group(1):                                       #PL: if( $cur_nest != $1 ) {
 150 | 5 |      |               cur_nest=new_nest=rematch.group(1)                # correct current nesting level
                                                                                                  #PL:                   $cur_nest=$new_nest=$1;
 151 | 5 |      |               InfoTags="=" + cur_nest                                           #PL: $InfoTags="=$cur_nest";
 152 | 4 |      |            else:                                                                #PL: else{
 153 | 5 |      |               InfoTags="OK " + cur_nest                                         #PL: $InfoTags="OK $cur_nest";
 155 | 3 |      |         elif line.re.match(r"^#%NEST++"):                                       #PL: elsif( $line =~ /^#%NEST++/) {
 156 | 4 |      |            cur_nest=new_nest=rematch.group(1)+1             # correct current nesting level
                                                                                                  #PL:                $cur_nest=$new_nest=$1+1;
 157 | 4 |      |            InfoTags='+1'                                                        #PL: $InfoTags='+1';
 158 | 3 |      |         elif line.re.match(r"^#%NEST--"):                                       #PL: elsif( $line =~ /^#%NEST--/) {
 159 | 4 |      |            cur_nest=new_nest=rematch.group(1)+1             # correct current nesting level
                                                                                                  #PL:                $cur_nest=$new_nest=$1+1;
 160 | 4 |      |            InfoTags='-1'                                                        #PL: $InfoTags='-1';
 161 | 3 |      |         elif line.re.match(r"^#%ZERO\?"):                                       #PL: elsif( $line =~ /^#%ZERO\?/) {
 162 | 4 |      |            if cur_nest==0:                                                      #PL: if( $cur_nest == 0 ) {
 163 | 5 |      |               InfoTags="OK " + cur_nest                                         #PL: $InfoTags="OK $cur_nest";
 164 | 4 |      |            else:                                                                #PL: else{
 165 | 5 |      |               InfoTags="??"                                                     #PL: $InfoTags="??";
 166 | 5 |      |               logme(['E',"Nest is " + cur_nest + " instead of zero. Reset to zero"]) #PL: logme('E',"Nest is $cur_nest instead of zero. Reset to zero");
 167 | 5 |      |               cur_nest=new_nest=0                                               #PL: $cur_nest=$new_nest=0;
 168 | 5 |      |               nest_corrections+=1                                               #PL: $nest_corrections++;
 172 | 2 |      |      process_line([line,-1000])                                                 #PL: process_line($line,-1000);
 173 | 2 |      |      continue                                                                   #PL: next;
 175 | 1 |      |   if line.re.match(r"^sub\s+(\w+)"):                                            #PL: if( $line =~ /^sub\s+(\w+)/ ){
 176 | 2 |      |      # $offset=-1;
 177 | 2 |      |      SubList[rematch.group(1)]=lineno                                           #PL: $SubList[$1]=$lineno;
 178 | 2 |      |      SubsNo+=1                                                                  #PL: $SubsNo++;
 179 | 2 |      |      if cur_nest!=0:                                                            #PL: if( $cur_nest != 0 ) {
Use of uninitialized value $1 in concatenation (.) or string at Perlscan.pm line 640, <> line 180.
 180 | 3 |      |         logme(['E',"Non zero nesting encounted for subroutine definition " + str()]) #PL: logme('E',"Non zero nesting encounted for subroutine definition $1");
 181 | 3 |      |         if cur_nest>0:                                                          #PL: if ($cur_nest>0) {
 182 | 4 |      |            InfoTags='} ?'                                                       #PL: $InfoTags='} ?';
 183 | 3 |      |         else:                                                                   #PL: else{
 184 | 4 |      |            InfoTags='{ ?'                                                       #PL: $InfoTags='{ ?';
 186 | 3 |      |         cur_nest=new_nest=0                                                     #PL: $cur_nest=$new_nest=0;
 187 | 3 |      |         nest_corrections+=1                                                     #PL: $nest_corrections++;
 190 | 1 |      |   if line=='__END__' or line=='__DATA__':                                       #PL: if( $line eq '__END__' || $line eq '__DATA__' ) {
 191 | 2 |      |      logme(['E',"Non zero nesting encounted for " + line])                      #PL: logme('E',"Non zero nesting encounted for $line");
 192 | 2 |      |      if cur_nest>0:                                                             #PL: if ($cur_nest>0) {
 193 | 3 |      |         InfoTags='} ?'                                                          #PL: $InfoTags='} ?';
 194 | 2 |      |      else:                                                                      #PL: else{
 195 | 3 |      |         InfoTags='{ ?'                                                          #PL: $InfoTags='{ ?';
 197 | 2 |      |      noformat=1                                                                 #PL: $noformat=1;
 198 | 2 |      |      here_delim='"'       # No valid here delimiter in this case !
                                                                                                  #PL:          $here_delim='"';
 199 | 2 |      |      InfoTags='DATA'                                                            #PL: $InfoTags='DATA';
 201 | 1 |      |   if line[0:1]=='=' and line!='=cut':                                           #PL: if( substr($line,0,1) eq '=' && $line ne '=cut' ){
 202 | 2 |      |      noformat=1                                                                 #PL: $noformat=1;
 203 | 2 |      |      InfoTags='POD'                                                             #PL: $InfoTags='POD';
 205 | 2 |      |      here_delim='=cut'                                                          #PL: }
 206 | 1 |      |
 207 | 1 |      |   # blank lines should not be processed
 208 | 1 |      |   if line.re.match(r"^\s*$"):                                                   #PL: if( $line =~/^\s*$/ ){
 209 | 2 |      |      process_line(['',-1000])                                                   #PL: process_line('',-1000);
 210 | 2 |      |      continue                                                                   #PL: next;
 212 | 1 |      |   # trim leading blanks
 213 | 1 |      |   if line.re.match(r"^\s*(\S.*$)"):                                             #PL: if( $line=~/^\s*(\S.*$)/){
 214 | 2 |      |      line=rematch.group(1)                                                      #PL: $line=$1;
 216 | 1 |      |   # comments on the level of nesting 0 should be shifted according to nesting
 217 | 1 |      |   if line[0:1]=='#':                                                            #PL: if( substr($line,0,1) eq '#' ){
 218 | 2 |      |      process_line([line,0])                                                     #PL: process_line($line,0);
 219 | 2 |      |      continue                                                                   #PL: next;
 221 | 1 |      |
 222 | 1 |      |   # comments on the level of nesting 0 should start with the first position
 223 | 1 |      |   first_sym=line[0:1]                                                           #PL: $first_sym=substr($line,0,1);
 224 | 1 |      |   last_sym=line[-1:1]                                                           #PL: $last_sym=substr($line,-1,1);
 225 | 1 |      |   if first_sym=='{' and len(line)==1:                                           #PL: if( $first_sym eq '{' && length($line)==1 ){
 226 | 2 |      |      process_line(['{',0])                                                      #PL: process_line('{',0);
 227 | 2 |      |      cur_nest=new_nest+=1                                                       #PL: $cur_nest=$new_nest+=1;
 228 | 2 |      |      continue                                                                   #PL: next;
 229 | 1 |      |   elif first_sym=='}':                                                          #PL: elsif( $first_sym eq '}' ){
 230 | 2 |      |      cur_nest=new_nest-=1                                                       #PL: $cur_nest=$new_nest-=1;
 231 | 2 |      |      process_line(['}',0])       # shift "{" left, aligning with the keyword
                                                                                                  #PL:          process_line('}',0);
 232 | 2 |      |      if line[0:1]=='}':                                                         #PL: if( substr($line,0,1) eq '}' ){
 233 | 3 |      |         line=line[1:]                                                           #PL: $line=substr($line,1);
 235 | 2 |      |      while(line,0,1)==' '       #FAILTRAN
                                                                                                  #PL:          while( substr($line,0,1)
 236 | 3 |      |         line=line[1:]                                                           #PL: $line=substr($line,1);
 238 | 2 |      |      # Case of }else{
 239 | 2 |      |      if not last_sym=='{':                                                      #PL: unless( $last_sym eq '{') {
 240 | 3 |      |         process_line([line,0])                                                  #PL: process_line($line,0);
 241 | 3 |      |         continue                                                                #PL: next;
 244 | 1 |      |   # Step 2: check the last symbol for "{" Note: comments are prohibited on such lines
 245 | 1 |      |   if last_sym=='{' and len(line)>1:                                             #PL: if( $last_sym eq '{' && length($line)>1 ){
 246 | 2 |      |      process_line([line[0:-1],0])                                               #PL: process_line(substr($line,0,-1),0);
 247 | 2 |      |      process_line(['{',0])                                                      #PL: process_line('{',0);
 248 | 2 |      |      cur_nest=new_nest+=1                                                       #PL: $cur_nest=$new_nest+=1;
 249 | 2 |      |      continue                                                                   #PL: next;
 250 | 1 |      |   # if
 251 | 1 |      |   #elsif( $last_sym eq '}' && length($line)==1  ){
 252 | 1 |      |   # NOTE: only standalone } on the line affects effective nesting; line that has other symbols is assumed to be like if (...) { )
 253 | 1 |      |   # $new_nest-- is not nessary as as it is also the first symbol and nesting was already corrected
 254 | 1 |      |   #}
 255 | 1 |      |   process_line([line,offset])                                                   #PL: process_line($line,$offset);
 256 | 1 |      |
 257 | 0 |      |# while
  ... ... ...
```
