= THIS IS A PRE ANNONCEMENT =

Some organizations are now involved in converting thier Perl codebase into Python. The author previously particilated in  several projects of 
converting mainframe codebase into Unix and think that this area might be a useful expantion of his skills. 
 
Of course Perl 5 is here to stay (plase note what happened with people who were predicting the demise of Fortran ;-), but for some reason 
several orgnizatings are expressed interest in converting thier support script codebase into a single language. Most often this is Python. 
Ruby which is probably a better match for such a translation is seldom used. 

My feeling is that there should be some better tools for this particular task to lessen the costs, the time and effort. One trivial idea is to havea better, 
whitten with the knoledge of compiler technologogies (the author is former compiler writer) tool that falls into the catagory of medium sizecompliers with 
totalaffort around one man year or less. 

Assuming 10 lines per day of debugged code for task of complexity comparable with writing of compilers, the estimated size should be arounde 3-4K
lines of code. 

So far just an idea, althouth the prototype was already written. It might be wrong and it might be impossible to write usinguseful in less then 4K lines. 

In any case the idea of "fuzzy pythonizer" is to translate subset of Perl typically used in sysadmin scripts into Python, marking untranslatable statmements
or statements parts with appropriate comments using ombination of two approaches approaches

1. Fuzzy matching. The program will use a database of "normalized" patterns to translate some common statements. No machine learning algorithms or God forbid nueral netwroks will be used ;-). Some Prolog level staff at max. 
  
2. Recusive decent parsing 

Preliminary classification (and Kthuth old paper) suggests that around 20% of statments in a typical Perl sysadmin script can be fe found in
database, another 50% can be (inperfectly) tranlatated using recusive decent parser, 20% can be translated in part (and some useful hints 
can be provided) and 10% are non-translatable by automatic means without huge and unjustifiable increase of the complexity of such a tranlator.   

The most interesting part here is whther it is possible to match and mix those two parts into a usable prodduct.  

As this is a hobby project no timeline is provided, but the autho would appraciated comments and pointers for thos who are interestied in the final product.  
