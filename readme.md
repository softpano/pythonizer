## Translator from Perl to Python 
### THIS IS AN ANNOUNCEMENT FOR VERSION 0.8 of "FUZZY" TRANSLATOR/TRANSRIBER FROM PERL TO PYTHON 

This readme is for informational purposes only and is not intended to be updated often. More current information can be found at:  

- [Introduction](http://www.softpanorama.org/Scripting/Pythonorama/Python_for_perl_programmers/Pythonizer/index.shtml)
- [User Guide](http://www.softpanorama.org/Scripting/Pythonorama/Python_for_perl_programmers/Pythonizer/user_guide.shtml)
 

### Possible use cases

Some organizations are now involved in converting their old Perl codebase into other scripting languages, such as Python. But a more common task is to maintain existing Perl scripts, when the person who is assigned to this task known only Python (University graduates now typically know Python but not Perl and that creates difficulties in the old codebase maintenance).

In this case, a program that "explains" Perl constructs in Python terms would be extremely useful and, sometimes, a lifesaver. Of course, Perl 5 is here to stay (please note what happened with people who were predicting the demise of Fortran ;-), and in most cases, old scripts will stay too. In many cases conversion is not worth the effort, as the script still can be maintained in Perl.  But you need to understand the script you are maintaining and here pythonizer can help. 

The other role is to give a quick start for system administrators who know Perl well but want to learn Python (for example, who need to support researchers who work with Python), many older school sysadmins dislike Python and for a reason ;-). This way they can convert some of their small sysadmin scripts and try to debug them in Python, getting their feet wet, so to speak. And that allows to obtain a much better understanding as for whether the compete switch to Python makes sense in their particular situation or not. 

### Pre-pythonizer implements the first phaze of translation

The first pass is currently fully optional as the needed transformations of Perl code (moving subroutines up) and slight reformatting of Perlcode can be performed by other utilities, or manually. It just slightly increases the probability of more correct translation of the code. It reformats the code so that curvy brackets were mostly on separate lines (this was useful for pythonizer up to version 0.2; later versions  do not depend on this transformation.) 

It can be used as a separate program, which transforms initial Perl script creating a backup with the extension `.original`. The main useful function in the current version is refactoring of the Perl program by pushing subroutines up as in Python subroutines needs to be declared before use. 

After you convert the script via pythonizer, it usually does not contain syntax errors and you can start to modify statements translated incorrectly semantically one by one using Python interpreter. 

As you can guess pythonize sometimes has allergy to very complex Perl constructs and you either need to comment out those statements or simplify them before the translation. Version 0.8 deals better with statements with eliminated parenthesis (the format widely used in postfix if statements). Elimnating paranthesis become kind of fashion in Perl although this does not add much to readability and something de-parenthesized statement are ambiguous.  Pythonizer tries to keep up with this fashion, althouth properly parenthesized statements are often translated more correctly. 


See the [User Guide](http://www.softpanorama.org/Scripting/Pythonorama/Python_for_perl_programmers/Pythonizer/user_guide.shtml) for detail. 

### Pythonizer implements actual transformation of Perl into Python

Currently only few user options are supported (pythonizer -h provides a  list of options):  

Option | Description
------ | -----------
-w     | The width of the line of the protocol of translation.<br/>The default is 188
-v     | Verbosity <br/>`-v 0` -- minimal verbosity <br/>`-v 3` -- max verbosity; <br/> `-v`, `-vv` and `-vvv` -- forms to which most Unix users got used in other utilities
-t     | Tab size for generated code;<br/>The default is  `-t 4`
-r     | Refactor Perl code. If specified, before processing the script by the pythonizer, it  invokes the `pre_pythonizer` preliminary pass on the source code. Of course this can be  done only once and can be manually as a separate pass with more control,  but still this option is not completly usless, as it provides an integrated way to refactor the program. 

To try `pythonizer` you need to download files (as Zip archive -- GitHub creates zip from the latest posted verion on demand for you)  or replicate the directory via git . In the later case the main program and three modules mentioned about should be put into a separate directory. For example, `/opt/Pythonizer`

The directory into which the modules are downloaded  needs to be made available to Perl via PERL5LIB env variable or via -I option . 

ATTENTION PYTHON PROGRAMMERS: Environment varible PERL5LIB or option -I of the Perl interpreter should specify the directory with modules in order to run the pythonizer. Otherwise modules will NOT be found.   

You can run Pythonizer both in Cygwin and Linux. 

For initial testing to "pythonize" the test Perl script `/path/to/your/program.pl`  you need to use the something like: 

```
export PERL5LIB=~/Perl5/lib && ~/bin/pythonizer /path/to/your/program.pl
```

If the program runs to the end you will get "pythonized" text in /path/to/your/program.py

It also produces protocol of translation in /tmp/Pythonizer with "side by side" Perl and Python code, which allows you to analyse the protocol and detect places that need to be commented out and translated manually. 

If  `__DATA__` or `__END__` are used a separate file with  the extension  .data  (/path/to/your/program.data for the example above) will be created with  the content on this section of Perl script.


### HISTORY 

Oct 02, 2020: Version 0.8 was uploaded. It provides a more correct translation of array assignments. Some non-obvious bugs in translation were fixed. Now you need to specify PERL5LIB variable pointing it to the directory with modules to run the program. Global variable now are initialized after main sub to undef value to create a global namespace. Previously this was done incorrectly.  Simple installer for Python programmers who do not know much Perl was added. Users report that pythonizer proved to be very useful as a help for understanding Perl scripts by Python programmers. 

Sep 18, 2020: Version 0.7 was uploaded. This version creates of the list of global variables for each subroutine to maintain the same visibility in Python as in Perl and generates global statement with the list of such  variables that is inserted in each Python subroutine definition if pythonizer determined that this subroutine access global variables. 

Sep 08, 2020: Version 0.6 was uploaded. Generated source does not contain syntax errors and starts executing in Python interpreter till the first error. List on internal functions created. Translation of backquotes and open statement improved. This version proved to be quite usable for converting simple sysadmin scripts in  Perl, as a an exersize in learning Python. 

Aug 31, 2020: Version 0.5 was uploaded. Regular expression and tr function translation was improved. Substr function translation improved. Many other changes and  error corrections. Option -r (refactor) implemented to allow refactoring. By default loads and run pre-pythonlizer.pl. As it changes the source, creating a backup,  you need to run it only once.  

Aug 22, 2020: Version 0.4 was uploaded. The walrus operator and the f-strings now are used to translate Perl double quoted literals if option -p is set to 3 (default). In this version Python 3.8 is used as the target language. 

Aug 17, 2020: Version 0.3 was uploaded. Changes since version 0.2: default version of Python used is now version 3.8; option -p allows to set version 2 if you still need generation for Python 2.7 (more constructs will be untranslatable).  See user guide for details. 

Aug 05, 2020: Version 0.2 was uploaded. The initial version. 

#### Example of translation 

Here is an fragment of translation of pre-pythonizer.pl which exists in this repositorory. It demostrates how the current version performs on "sysadmin"/"text processing" subset of Perl:  

```Perl
   ... ... ...
 870 | 1 |      |   for lineno in range(lineno,len(SourceText)):                                  #PL: {
 871 | 2 |      |      line=SourceText[lineno]                                                    #PL: $line=$SourceText[$lineno];
 872 | 2 |      |      offset=0                                                                   #PL: $offset=0;
 873 | 2 |      |      line=line.rstrip("\n")                                                     #PL: chomp($line);
 874 | 2 |      |      intact_line=line                                                           #PL: $intact_line=$line;
 876 | 2 |      |      if lineno==breakpoint:                                                     #PL: {
 878 | 3 |      |         pdb.set_trace()                                                         #PL: }
 879 | 2 |      |
 880 | 2 |      |      line=([line])                                                              #PL: $line=normalize_line($line);
 881 | 2 |      |
 882 | 2 |      |      #
 883 | 2 |      |      # Check for HERE line
 884 | 2 |      |      #
 885 | 2 |      |
 887 | 2 |      |      if noformat:                                                               #PL: {
 889 | 3 |      |         if line==here_delim:                                                    #PL: {
 890 | 4 |      |            noformat=0                                                           #PL: $noformat=0;
 891 | 4 |      |            InfoTags=''                                                          #PL: $InfoTags='';
 893 | 3 |      |
 894 | 3 |      |         process_line([line,-1000])                                              #PL: process_line($line,-1000);
 895 | 3 |      |         continue                                                                #PL: next;
 897 | 2 |      |
 898 | 2 |      |
 900 | 2 |      |      if (default_match:=re.match("""<<['"](\w+)['"]$""",line)): #PL: {
 901 | 3 |      |         here_delim=default_match.group(1)                                       #PL: $here_delim=$1;
 902 | 3 |      |         noformat=1                                                              #PL: $noformat=1;
 903 | 3 |      |         InfoTags='HERE'                                                         #PL: $InfoTags='HERE';
 905 | 2 |      |
 906 | 2 |      |      #
 907 | 2 |      |      # check for comment lines
 908 | 2 |      |      #
 910 | 2 |      |      if line[0]=='#':                                                           #PL: {
 912 | 3 |      |         if line=='#%OFF':                                                       #PL: {
 913 | 4 |      |            noformat=1                                                           #PL: $noformat=1;
 914 | 4 |      |            here_delim='#%ON'                                                    #PL: $here_delim='#%ON';
 915 | 4 |      |            InfoTags='OFF'                                                       #PL: $InfoTags='OFF';
 918 | 3 |      |         elif re.match(r'^#%ON',line):                                           #PL: {
 919 | 4 |      |            noformat=0                                                           #PL: $noformat=0;
 922 | 3 |      |         elif line[0:6]=='#%NEST':                                               #PL: {
 924 | 4 |      |            if (default_match:=re.match(r'^#%NEST=(\d+)',line)): #PL: {
 926 | 5 |      |               if cur_nest!=default_match.group(1):                              #PL: {
 927 | 6 |      |                  cur_nest=new_nest=default_match.group(1)                   # correct current nesting level
                                                                                                  #PL:                         $cur_nest=$new_nest=$1;
 928 | 6 |      |                  InfoTags=f"={cur_nest}"                                        #PL: $InfoTags="=$cur_nest";
 931 | 5 |      |               else:                                                             #PL: {
 932 | 6 |      |                  InfoTags=f"OK {cur_nest}"                                      #PL: $InfoTags="OK $cur_nest";
 934 | 5 |      |
 937 | 4 |      |            elif re.match(r'^#%NEST++',line):                                    #PL: {
 938 | 5 |      |               cur_nest=new_nest=default_match.group(1)+1                # correct current nesting level
                                                                                                  #PL:                     $cur_nest=$new_nest=$1+1;
 939 | 5 |      |               InfoTags='+1'                                                     #PL: $InfoTags='+1';
 942 | 4 |      |            elif re.match(r'^#%NEST--',line):                                    #PL: {
 943 | 5 |      |               cur_nest=new_nest=default_match.group(1)+1                # correct current nesting level
                                                                                                  #PL:                     $cur_nest=$new_nest=$1+1;
 944 | 5 |      |               InfoTags='-1'                                                     #PL: $InfoTags='-1';
 947 | 4 |      |            elif re.match(r'^#%ZERO\?',line):                                    #PL: {
 949 | 5 |      |               if cur_nest==0:                                                   #PL: {
 950 | 6 |      |                  InfoTags=f"OK {cur_nest}"                                      #PL: $InfoTags="OK $cur_nest";
 953 | 5 |      |               else:                                                             #PL: {
 954 | 6 |      |                  InfoTags='??'                                                  #PL: $InfoTags="??";
 955 | 6 |      |                  logme(['E',f"Nest is {cur_nest} instead of zero. Reset to zero"]) #PL: logme('E',"Nest is $cur_nest instead of zero. Reset to zero");
 956 | 6 |      |                  cur_nest=new_nest=0                                            #PL: $cur_nest=$new_nest=0;
 957 | 6 |      |                  nest_corrections+=1                                            #PL: $nest_corrections++;
 959 | 5 |      |
 961 | 4 |      |
 963 | 3 |      |
 964 | 3 |      |         process_line([line,-1000])                                              #PL: process_line($line,-1000);
 965 | 3 |      |         continue                                                                #PL: next;
 967 | 2 |      |
 969 | 2 |      |      if (default_match:=re.match(r'^sub\s+(\w+)',line)):                        #PL: {
 970 | 3 |      |         SubList[default_match.group(1)]=lineno                                  #PL: $SubList{$1}=$lineno;
 971 | 3 |      |         SubsNo+=1                                                               #PL: $SubsNo++;
 972 | 3 |      |         ChannelNo=2                                                             #PL: $ChannelNo=2;
 973 | 3 |      |         CommentBlock=0                                                          #PL: $CommentBlock=0;
 975 | 3 |      |         for backno in range(len(FormattedMain)-1,0,-1):                         #PL: {
 976 | 4 |      |            comment=FormattedMain[backno]                                        #PL: $comment=$FormattedMain[$backno];
 978 | 4 |      |            if re.match(r'^\s*#',comment) or re.match(r'^\s*$',comment): #PL: {
 979 | 5 |      |               CommentBlock+=1                                                   #PL: $CommentBlock++;
 982 | 4 |      |            else:                                                                #PL: {
 983 | 5 |      |               break                                                             #PL: last;
 985 | 4 |      |
 987 | 3 |      |
 988 | 3 |      |         backno+=1                                                               #PL: $backno++;
 990 | 3 |      |         for backno in range(backno,len(FormattedMain)):                         #PL: {
 991 | 4 |      |            comment=FormattedMain[backno]                                        #PL: $comment=$FormattedMain[$backno];
 992 | 4 |      |            process_line([comment,-1000])             #copy comment block from @FormattedMain were it got by mistake
                                                                                                  #PL:                 process_line($comment,-1000);
 994 | 3 |      |
 996 | 3 |      |         for backno in range(0,CommentBlock):                                    #PL: {
 997 | 4 |      |            FormattedMain.pop()             # then got to it by mistake
                                                                                                  #PL:                 pop(@FormattedMain);
 999 | 3 |      |
1001 | 3 |      |         if cur_nest!=0:                                                         #PL: {
1002 | 4 |      |            logme(['E',f"Non zero nesting encounted for subroutine definition {default_match.group(1)}"]) #PL: logme('E',"Non zero nesting encounted for subroutine definition $1");
1004 | 4 |      |            if cur_nest>0:                                                       #PL: {
1005 | 5 |      |               InfoTags='} ?'                                                    #PL: $InfoTags='} ?';
1008 | 4 |      |            else:                                                                #PL: {
1009 | 5 |      |               InfoTags='{ ?'                                                    #PL: $InfoTags='{ ?';
1011 | 4 |      |
1012 | 4 |      |            nest_corrections+=1                                                  #PL: $nest_corrections++;
1014 | 3 |      |
1015 | 3 |      |         cur_nest=new_nest=0                                                     #PL: $cur_nest=$new_nest=0;
1018 | 2 |      |      elif line=='__END__' or line=='__DATA__':                                  #PL: {
1019 | 3 |      |         ChannelNo=3                                                             #PL: $ChannelNo=3;
1020 | 3 |      |         logme(['E',f"Non zero nesting encounted for {line}"])                   #PL: logme('E',"Non zero nesting encounted for $line");
1022 | 3 |      |         if cur_nest>0:                                                          #PL: {
1023 | 4 |      |            InfoTags='} ?'                                                       #PL: $InfoTags='} ?';
1026 | 3 |      |         else:                                                                   #PL: {
1027 | 4 |      |            InfoTags='{ ?'                                                       #PL: $InfoTags='{ ?';
1029 | 3 |      |
1030 | 3 |      |         noformat=1                                                              #PL: $noformat=1;
1031 | 3 |      |         here_delim='"'          # No valid here delimiter in this case !
                                                                                                  #PL:             $here_delim='"';
1032 | 3 |      |         InfoTags='DATA'                                                         #PL: $InfoTags='DATA';
1034 | 2 |      |
1036 | 2 |      |      if line[0]=='=' and line!='=cut':                                          #PL: {
1037 | 3 |      |         noformat=1                                                              #PL: $noformat=1;
1038 | 3 |      |         InfoTags='POD'                                                          #PL: $InfoTags='POD';
1040 | 3 |      |         here_delim='=cut'                                                       #PL: }
1041 | 2 |      |
1042 | 2 |      |
1043 | 2 |      |      # blank lines should not be processed
1045 | 2 |      |      if re.match(r'^\s*$',line):                                                #PL: {
1046 | 3 |      |         process_line(['',-1000])                                                #PL: process_line('',-1000);
1047 | 3 |      |         continue                                                                #PL: next;
1049 | 2 |      |
1050 | 2 |      |      # trim leading blanks
1052 | 2 |      |      if (default_match:=re.match(r'^\s*(\S.*$)',line)):                         #PL: {
1053 | 3 |      |         line=default_match.group(1)                                             #PL: $line=$1;
1055 | 2 |      |
1056 | 2 |      |      # comments on the level of nesting 0 should be shifted according to nesting
1058 | 2 |      |      if line[0]=='#':                                                           #PL: {
1059 | 3 |      |         process_line([line,0])                                                  #PL: process_line($line,0);
1060 | 3 |      |         continue                                                                #PL: next;
1062 | 2 |      |
1063 | 2 |      |
1064 | 2 |      |      # comments on the level of nesting 0 should start with the first position
1065 | 2 |      |      first_sym=line[0]                                                          #PL: $first_sym=substr($line,0,1);
1066 | 2 |      |      last_sym=line[-1]                                                          #PL: $last_sym=substr($line,-1,1);
1068 | 2 |      |      if first_sym=='{' and len(line)==1:                                        #PL: {
1069 | 3 |      |         process_line(['{',0])                                                   #PL: process_line('{',0);
1070 | 3 |      |         cur_nest=new_nest=new_nest+1                                            #PL: $cur_nest=$new_nest+=1;
1071 | 3 |      |         continue                                                                #PL: next;
1074 | 2 |      |      elif first_sym=='}':                                                       #PL: {
1075 | 3 |      |         cur_nest=new_nest=new_nest-1                                            #PL: $cur_nest=$new_nest-=1;
1076 | 3 |      |         process_line(['}',0])          # shift "{" left, aligning with the keyword
                                                                                                  #PL:             process_line('}',0);
1078 | 3 |      |         if line[0]=='}':                                                        #PL: {
1079 | 4 |      |            line=line[1:]                                                        #PL: $line=substr($line,1);
1081 | 3 |      |
1083 | 3 |      |         while line[0]==' ':                                                     #PL: {
1084 | 4 |      |            line=line[1:]                                                        #PL: $line=substr($line,1);
1086 | 3 |      |
1087 | 3 |      |         # Case of }else{
1089 | 3 |      |         if not last_sym=='{':                                                   #PL: {
1090 | 4 |      |            process_line([line,0])                                               #PL: process_line($line,0);
1091 | 4 |      |            continue                                                             #PL: next;
1093 | 3 |      |
1095 | 3 |      |         if cur_nest==0:                                                         #PL: {
1096 | 4 |      |            ChannelNo=1             # write to main
                                                                                                  #PL:                 $ChannelNo=1;
1098 | 3 |      |
1100 | 2 |      |
1101 | 2 |      |      # Step 2: check the last symbol for "{" Note: comments are prohibited on such lines
1103 | 2 |      |      if last_sym=='{' and len(line)>1:                                          #PL: {
1104 | 3 |      |         process_line([line[0:-1],0])                                            #PL: process_line(substr($line,0,-1),0);
1105 | 3 |      |         process_line(['{',0])                                                   #PL: process_line('{',0);
1106 | 3 |      |         cur_nest=new_nest=new_nest+1                                            #PL: $cur_nest=$new_nest+=1;
1107 | 3 |      |         continue                                                                #PL: next;
1109 | 2 |      |      # if
1110 | 2 |      |      #elsif( $last_sym eq '}' && length($line)==1  ){
1111 | 2 |      |      # NOTE: only standalone } on the line affects effective nesting; line that has other symbols is assumed to be like if (...) { )
1112 | 2 |      |      # $new_nest-- is not nessary as as it is also the first symbol and nesting was already corrected
1113 | 2 |      |      #}
1114 | 2 |      |      process_line([line,offset])                                                #PL: process_line($line,$offset);
1116 | 1 |      |   # while
```

