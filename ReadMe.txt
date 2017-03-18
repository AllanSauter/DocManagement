Documentation Management Software package
aws 2016 04 10  

For the purpose of merging, or trimming directories of information, and keeping databases current, I have written some perl scripts to help you with these tasks.  I will describe each tool and its use.

makeout.pl - given a directory input name, this program creates a text outline
----------------------
perl makeout.pl OutDir [-f]
----------------------
labeled: Outlineyyyymmdd_hhmm.txt listing all directories and subdirectories
in clade order. Note that -f option includes all files listed in each subdir,
but this part hasn't been written as of 20160411

suboscar.pl - outline syntax checker and repairer.  
-------------------------------------------------
perl suboscar.pl Outline.txt Output.txt
-------------------------------------------------
Note Output.txt is experimental at this stage in suboscar development.

WipIt.pl - preferred tool for maintaining a website -
-------------------------------
perl WipIt.pl WriteDir InputDir 
-------------------------------
You specify an output directory and an input directory.  
All matched files between WriteDir and InputDir result in the
overlay of the InputDir version onto the WriteDir (-o option, in overlays
write regardless of date, no -o option, newest files remain in WriteDir.
InputDir subdirs that have at least a depth of 2 can be spliced onto WriteDir
if all of InDir path matches WriteDir's.

direct.pl - creates and or fills WriteDir as outlined in Outline.txt. 
------------------------------------------------------------
perl direct.pl Outline.txt WriteDir InDir1 [InDir2 -a -o -u] 
------------------------------------------------------------
Files come from InDir1 & InDir2 - requires matching at least 2 levels of 
direct ancestor directories to avoid unwanted aliasing. It allows 3 flags 
(-a for archiving older, replaced files, 
-o for structuring WriteDir to exactly match Outline.txt, as opposed to 
no -o option, which allows initial WriteDir structure to remain,  
-u for writing InDir2 files on top of any same-named, but different files 
 in WriteDir regardless which is newer, as opposed to 
no -u option where the newest version remains in WriteDir.
It consists of 3 subroutines:
 &ReadOut - reads the outline file and creates a @pages array
 &BuildDir - Creates, if not already in existence, all folders listed
               in the outline
 &FillDir - copies files from InDir1 and InDir2 into WriteDir

BuildIt.pl - makes a cohesive, reachable, downloadable website out of a
directory system 
------------------------
perl BuildIt.pl WriteDir
------------------------ 
***Note*** BuildIt.pl requires the CPAN module File::Slurp be loaded into the
How to get perl modules in ActiveState perl - 
open dos window and type ppm - a gui will open - be patient, then click on the 
icon below File (search all packages)  Filter with File-Slurp, then click on 
it in the list below, then click on the box labeled Mark for Install to the 
right of the search window - then click on the green arrow to the right of it -
 takes a while, but the details window below will show it being installed and 
when it is finished installing machine running perl (type ppm [return] in dos 
window - 

BuildIt recursively crawls through WriteDir, checking and reporting on
inconsistencies between the index.htm file in each subdirectory, and the
content of that subdirectory.  All index.htm files are rebuilt and rewritten
in each subdirectory























































































































































































































































































































































































