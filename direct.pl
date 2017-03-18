#!/usr/bin/perl
# usage: perl direct.pl Outline.txt WriteDir InDir1 [InDir2 -o -u -a]  
#
######################################################
#	August 17, 2015
######################################################
#  This script creates or fills WriteDir, built to match the
#    structure of Outline.txt, with files populated with InDir1 & 2.
#    Directories with common names:  Procedures, Configurations, and others
#    require matching at least 2 levels of directories, to avoid unwanted 
#    collisions.
#
#   It parses through the file Outline.txt, building WriteDir as specified, 
#   populating it with files from the InDir1 & 2 directories and 
#   building default index.htm files for directories where they don't exist.
#  
#   After the WriteDir is populated, &BuildWeb searches for index.htm pages,
#   checks for consistency, and builds one for each directory where they don't 
#   exist.  The types built depend on the directory contents as deduced and
#   coded in the $pages[$line#][6] =
#    1) 3, default "no content" pages for directories with no content
#    2) 1, single image pages for directories that have a single image 
#      2a) if there are sub-directories present, with content (Value !=3 or 1)
#         this content is hidden from browser view and needs to be reported 
#         because human intervention is required to restore the hidden info 
#    3) List html pages that are the form of /Procedures/index.htm pages
#    4) Other pages - for directories that have subdirectory structure, but not
#       enough content to definitively build the web structure.
#   Note that a R_YYYYMMDD_hhmm.txt file is built to report page locations for
#     types 1), 2a, and 4)
#
#   Note that files in InDir2 will overwrite files entered from InDir1, if 
#    newer, or if the -u (overwrite) option is specified - 
#    If all you want to do is update a directory structure from an Inbox, use 
#     the perl script WipIt.pl 
#     -o option clears WriteDir before starting and only builds it to match 
#        the structure of Outline.txt - no extra subdirectory info not 
#        specified by Outline.txt is added to WriteDir
#     -u option overwrites matching files in WriteDir from InDir2 files 
#        regardless of edit date ( way to recover older files )
#     -a option specifies an archive folder be written in each directory of
#        WriteDir with a file about to br replaced
#
use File::Path;
use File::Copy;
use File::Find;
use File::Copy::Recursive qw(fcopy rcopy dircopy fmove rmove dirmove);
use File::Compare;
#	if (compare("file1","file2") == 0) {
#	    print "They're equal\n";  
#	}
use Cwd;
my ($InDir1, $InDir2);
my $depth =0; #recursion depth for WipIt
my @FFSplit;
my @Pages;
my (@Matchd, @Matchf);
my @Match; #Keeps track of full folder pathnames InDir1 and InDir2 
           #  that match $pages[$i][0]  (FillDir
my $i;
my $FindFill;
my @fullfiles;
my @justfile;
my $LookFor;
my ($OutlineFile, $WriteDir);
my $Oflag = 0;
my $Uflag = 0;
my $Aflag = 0; #Archiving not done unless -a argument is set to set $Aflag = 1
#
if ($#ARGV < 2 | $#ARGV > 6) {#note to self: remember $# holds the last array 
	                      # index, which is one less than the actual array 
			      # member count
	print "usage: perl direct.pl Outline WriteDir InDir1 [InDir2 -o -u -a]\n";
	print "or: perl direct.pl WriteDir InDir1 (same as call to WipIt.pl\n";
	exit;
}
$OutlineFile = $ARGV[0];
my $mydir;
#print ("outline file = $OutlineFile\n ");
$WriteDir = $ARGV[1];
$InDir1 = $ARGV[2];
# get $InDir2 and set flags depending arguments
if ($#ARGV > 2 && ($ARGV[3] ne '-u') && ($ARGV[3] ne '-o') && ($ARGV[3] ne '-a')){
	$InDir2 = $ARGV[3];
}
elsif ($ARGV[3] eq '-u') {
	$Uflag = 1;
}
elsif ($ARGV[3] eq '-o') {
	$Oflag = 1;
}
elsif ($ARGV[3] eq '-a') {
	$Aflag = 1;
}
if ($#ARGV > 3 && ($ARGV[4] ne '-u') && ($ARGV[4] ne '-o') && ($ARGV[4] ne '-a')){
	$InDir2 = $ARGV[4];
}
elsif ($ARGV[4] eq '-u') {
	$Uflag = 1;
}
elsif ($ARGV[4] eq '-o') {
	$Oflag = 1;
}
elsif ($ARGV[4] eq '-a') {
	$Aflag = 1;
}
if ($#ARGV > 4 && ($ARGV[5] ne '-u') && ($ARGV[5] ne '-o') && ($ARGV[5] ne '-a')){
	$InDir2 = $ARGV[5];
}
elsif ($ARGV[5] eq '-u') {
	$Uflag = 1;
}
elsif ($ARGV[5] eq '-o') {
	$Oflag = 1;
}
elsif ($ARGV[5] eq '-a') {
	$Aflag = 1;
}
if ($#ARGV > 5 && ($ARGV[6] ne '-u') && ($ARGV[6] ne '-o') && ($ARGV[6] ne '-a')){
	$InDir2 = $ARGV[6];
}
elsif ($ARGV[6] eq '-u') {
	$Uflag = 1;
}
elsif ($ARGV[6] eq '-o') {
	$Oflag = 1;
}
elsif ($ARGV[6] eq '-a') {
	$Aflag = 1;
}
if ($#ARGV == 2) {
	$WriteDir = $ARGV[0];
	$InDir1 = $ARGV[1];
	#Outline is ignored
	&WipIt($depth, $InDir1);
	&BuildWeb;
	&ZeroPadDir;
	exit;
}

if ($Oflag){
	if (-e $WriteDir and -d $WriteDir){
		print "Note - $WriteDir exists and will be overwritten if you type y\n";
		my $answer = <STDIN>;
		if ($answer ne 'y'){
			print ("exiting - if you want to keep $WriteDir, remove -o option\n");
			exit;
		}
		else {
			remove_tree($WriteDir);
		}
	}
}
my $time = &TimeStamp();
my $Outstring = "Report$time.txt"; #Report file
open(REPORT,">>$Outstring") || die ("Couldn't open $Outstring\n");
print REPORT "Date: $Outstring\n";
print REPORT "Outline: $OutlineFile \n";
print REPORT "NewDir: $WriteDir\n";
print REPORT "InDir1: $InDir1\n";
print REPORT "InDir2: $InDir2\n"; #8 preceding lines write a report header 
#############################################################################
#THE ARRAY'S STRUCTURE IS AS FOLLOWS
# $pages[line number][0] = folder name  - e.g. Vaisala
# $pages[line number][1] = folder location with respect to the root.
#                                     e.g.    /INSTALL/PREVIE/Vaisala 
# $pages[line number][2] = number of spaces (to denote folder hierarchy)
# $pages[line number][3] = Enumerator.  e.g. A.   (note period 
# $pages[line number][4] = picture name (i.e. TABaler.png)
# $pages[line number][5] = Orginal, unedited Outline line
# $pages[line number][6] = error bit code. 0 = no errors to report
#                           1 bit set = no index.htm found
#                           2 bit set = no image file found
#                           4 bit set = index.htm & @pages image don't match
#                           8 bit set = archived file
#                          16 bit set = ImageFile not specified in index.htm 
#                          32 bit set = index.htm image file name
#                             inconsistency (differing names in <img src line
#                          64 bit set = index.htm map file name(s) not right 
#                         128 bit set = index.htm map file name(s) not right 
#############################################################################

#print "\nProgram Starting\n";

&ReadOut($OutlineFile); #  version rewritten from ParseOutline (wip.pl:337-473 
&BuildDir; # version of &MakeOutlineFolders
&FillDir; #
&BuildWeb;
&ZeroPadDir; #new, but may be implemented somewhere in wip.pl
	# This routine builds needed html code where no documentation exists 
	#
	#Not sure I need the 4 routines below, but they're there for reference
close (REPORT);
&MakeOutlineFolders;
&InboxFolderCopy;
&InboxFileCopy;
&FindIndex_html;


#################################
#ReadOut Subroutine - reads the outline file ($OutlineFile) 
#              and transfers the information to @pages:
#              [0]= folder name  - e.g. Vaisala
#              [1]= folder location with respect to the root (.)
#                               e.g.    /INSTALL/PREVIE/Vaisala 
#              [2] = number of spaces before enumerator 
#              [3] = Enumerator.  e.g. A.   (note period is included 
#              [4] = picture name (i.e. TABaler.png)
#              [5] = Orginal, unedited Outline line
#   note that  [6] = error flags is filled in FillDir
#################################

sub ReadOut {
	my $Outline = @_[0];
        my $array_count = 0;
	my $line;
	my $heading;
	my $page;
	my $picture;
	my $temppage;
	my $number_of_spaces;
	my ($n, $ln);
	open(OUTLINE, "$Outline") || die("OUTLINE FILE NOT FOUND.\n");
	foreach $line (<OUTLINE>)
	{
		$pages[$array_count][5] = $line;
		chomp($line);  #remove trailing newline \n
		if($line =~/\.\s/){  # if the line has a ". " in it, 
			     # split between the enumerator  (e.g. A., I., 1.)
			     # and the content portion 
			     #                (e.g. SolarPanel:SolarPanel.png)
			($heading,$page) = split(/\. /,$line);#split between the 
		             # outline heading  (eg: A   I     1       a  ... 
			     # including spaces) and content portion:
			     # (SolarPanel:SolarPanel.png)
			$number_of_spaces = 0;
			$heading =~ s/^(\s*)//;
			$number_of_spaces = length($1);
			$pages[$array_count][3] = "$heading .\.";#Save enumerator,
			#	including period to @pages[3] 
			$temppage = $page;
	
			chomp($temppage);


			($page,$picture) = split(/:/,$temppage);#note that if 
			   # there is no :, $page gets the whole thing and
			   #   $picture is null
			chomp($picture);
			#print ("$picture\n");
			if($picture =~/,$/){
				print ("picture $picture\n");
				chop($picture);
			}
			$pages[$array_count][0] = $page;

			#print ("$page Pages[0]\n");
			$pages[$array_count][2] = $number_of_spaces;
			$pages[$array_count][4] = $picture;
		}else{     # lines w/o enumerators are  most likely procedure/
			   #  configuration files

			#removes leading and trailing whitespaces and last ,
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			if($line =~/,$/ or $line=~/;$/){chop($line)};
			if($line =~/,/){
				print("Too many commas line: $array_count\n");
				exit;
			}
	
			#Someday I may need to add a routine to split the line at
			# parsing marks, e.g. "," for lines that have multiple 
			# file names in it.  But for now the rule is one file per
			# line in the outline.
			#Check for filename syntax (I suspect this reg expression
			#                          is too strict - scrub for now):
			#if ($line !=~/^[\w,\s-]+\.[A-Za-z0-9]{3}$/ {
			#	print ("$line at $array_count incorrect\n");
			#	exit;
			#}
			#print "\n\n\tline: $line\n";
			#getc();
			if ($array_count == 0) {
				print ("error - first line needs enumerator\n");
				exit;
			}
			#  below we update directory and enumerator info for 
			#  file line
			$pages[$array_count][0] = $pages[$array_count-1][0];
			$pages[$array_count][1] = $pages[$array_count-1][1];
			$pages[$array_count][2] = $pages[$array_count-1][2];
			$pages[$array_count][3] = $pages[$array_count-1][3];
			$pages[$array_count][4] = $line;

		}
		
		#print "Page: $pages[$array_count][0]\n";
		#print "Numb of Spaces: $pages[$array_count][1]\n";
		#print "Picture: $pages[$array_count][4]\n\n";

		#getc();
		
		$array_count++;
	}
	close(OUTLINE);	
#################################
#CONVERT OUTLINE INTO DIRECTORIES  - Build pages [$i][1] full folder name
#################################
	for $i (0 .. $#pages) {
		#print "\t # $i is [ $pages[$i][2] ], \n";
		$n = 1;
		if ($pages[$i][2] == 0) {  # in root directory
			#print ("WriteDir= $WriteDir\n");
			$pages[$i][1] = $WriteDir."/".$pages[$i][0];
			#print ("$pages[$i][1]= pages $i,1\n");
		}
		elsif ($pages[$i][2] == $pages[$i-1][2] + 1) { # true if current 
		   #line is a child of the previous line
			$pages[$i][1] = $pages[$i-1][1]."/".$pages[$i][0];
		}
		
		elsif($pages[$i][2] == $pages[$i-1][2]){ # true if current line 
			# is a sibling of the previous line
			do{	$n++;  #  do loop to find the parent line
				#print "\n",$n;
				#getc();
			 if($pages[$i][2] > $pages[$i-$n][2]){  # true when the 
			  #parent line is found
				$pages[$i][1] = $pages[$i-$n][1]."/"
					.$pages[$i][0];
			 }
			}while($pages[$i][2] <= $pages[$i-$n][2]);
		}
		elsif($pages[$i][2] < $pages[$i-1][2]){  #this line is not a 
			# child or sibling of the previous line
			do{	$n++;   # find its parent line
				if($pages[$i][2] > $pages[$i-$n][2]){ # true when 
				   #  parent line is found
					$pages[$i][1] = $pages[$i-$n][1]."/"
						.$pages[$i][0];
				}
			}while($pages[$i][2] <= $pages[$i-$n][2]);		
		}
		else{  #this line doesn't follow good outline syntax - 
			#report it - I doubt this will happen in a real outline
			print ("bad line: Preceding line: $pages[$i-1][1]\n");
			print ("bad line: This line: $pages[$i][1]\n");
			$ln = $i +1;
			print ("bad line: $ln\n");
			exit;

		}
	}
}
#####################################
# CREATE FOLDERS BASED ON THE OUTLINE
#   - This subroutine creates a directory structure based on 
#   @pages with WriteDir being the root
#####################################
sub BuildDir{

 BUILD: for $i (0 .. $#pages){
		unless ($i ==0) 
		  {next BUILD if ($pages[$i][1] eq $pages[$i-1][1])};
		  #print ("faildir: $pages[$i][1]\n");#
		  mkpath($pages[$i][1]);	
		eval {mkpath($pages[$i][1])};
			if($@){print "Couldn't make the dir: $@";}
	}
}

sub FillDir {
my @MatchRank; #Keeps track of closeness of pathname match the bigger
                  # the number, the more ancestors in common, the better the
		  # match. This is the counter that keeps track of the number
	          # succeeding matching directories (i.e. parent matches, 
		  #  grandparent matches, great- ...)
my @M_plus_R; # @M_plus_R[$i][$j] = @Match[$i]@MatchRank[$j] for sorting
                  #   by rank
my @genx;
my @geny;
my $OccamMatch;
my @PathLength;
my $MinPathLength;
my $GotEm = 0;
my @filenames;
my @all;
my $mat;
my $num;
my ($j, $k, $l, $m, $n, $MatchNo, $count, $got_it);
my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev);
my ($size,$atime,$mtimeIn,$ctime,$blksize,$blocks);
my $mtimeWrite;
my $Ark;
 
BLK0: for $i (0 .. $#pages) {  # going thru the full outline, copying files
#First, go through matches in InDir1 (lines 28 - 
	$#Match = -1; # zero the array before rebuilding
	$#MatchRank = -1; # zero the array before rebuilding
	$#M_plus_R = -1; # zero the array before rebuilding
	$MatchNo = 0;
	$#fullfiles = -1;
	$#PathLength = -1;
	$#justfile = -1;
	$GotEm = 0;
	$#geny = -1; # zero the array before rebuilding
	$#genx = -1; # zero the array before rebuilding
	#print ("$pages[$i][0] before Wanted2\n");
	$FindFill = $pages[$i][0];
	find(\&Wanted2, $InDir1); # this loads matching folder names from
	                         #  InDir1 into an array @Match
	#print ("looking for: $FindFill\n");
	#print ("Matches:\n");
	#for ($j =0; $j<=$#Match; $j++){
	#	print ("$Match[$j] ");
	#}
	#print ("\n");
	@geny = split(/\//, $pages[$i][1]); #break pathname into 
		                          # directory elements
	@geny = reverse @geny;
	if ($#Match >-1){
		#	print ("number of matches = $#Match, $Match[0], $Match[1]\n");
	}

	for ($m=0; $m<=$#Match; $m++) { # for each match, determine the 
		                   # number of matching directories
				   # with target $pages[$i][1]
		@genx = split(/\//, $Match[$m]); #break InDir1 pathname
		                            # into directory elements
		#print ("InDir1 - @genx\n"); #debug line
		#print ("LineNo - @geny\n"); #debug line
		@genx = reverse @genx;
		#print ("InDir1rev - @genx\n"); #debug line
		#print ("LineNoRev - @geny\n"); #debug line
		$PathLength[$m] = $#genx;
		if ($#genx > $#geny) {
			$count = $#geny;
		}
		else {
			$count = $#genx;
		}
		for ($j=0; $j <=$count; $j++){ # determine number of
		                              # generations that match
					      # between $pages and 
					      # $InDir1
			if($genx[$j] eq $geny[$j]){
				#print ("gx $genx[$j], gy $geny[$j], $MatchRank[$MatchNo], count$count\n");
				$MatchRank[$m] += 1;
				print ("MatchRank = $MatchRank[$m]\n");
				#print ("MatchRank should never be 0=$MatchRank[$MatchNo]\n");
			}
			else {
				last;
 			}
		}		
	}
	if ($#Match >= 0){
	 $M_plus_R[0] = [@Match];
	 $M_plus_R[1] = [@MatchRank];
	 print ("M+R0 before transpose\n");
	 for ($j = 0; $j<=1; $j++){
		 for ($k = 0; $k <=$#Match;$k++){
	  		print ("$M_plus_R[$j][$k] "); 
		}
		print ("\n");
	 }
	 for $j (0 .. $#Match) { # Transpose matrix to make sorting possible
		 for $k (0 .. $j -1){ # swap rows for columns
			 ($M_plus_R[$j][$k], $M_plus_R[$k][$j]) =
			 ($M_plus_R[$k][$j], $M_plus_R[$j][$k]);
		 }
	 }
	 if ($#Match == 0){
		 $M_plus_R[0][1] = 1;
	 }
	 print ("Matches before sort - # of matches: $#Match\n");
	 for ($j = 0; $j<=$#Match; $j++){
		 for ($k = 0; $k <=1;$k++){
	  		print ("$M_plus_R[$j][$k] "); 
		}
		print ("\n");
	 }
	 @M_plus_R = sort {$b->[1] <=> $a->[1]} @M_plus_R;
	 print ("Matches after sort: \n");
	 for ($j = 0; $j<=$#Match; $j++){
		 for ($k = 0; $k <=1;$k++){
	 		print ("$M_plus_R[$j][$k] "); 
		}
		print ("\n");
	 }
	  $OccamMatch = 0;
	  $MinPathLength = $PathLength[0];
	print ("# matches = $#Match, #Pathlengths = $#PathLength, pathlength = $PathLength[0] ");
  BLK1: for ($j = 0; $j < $#Match; $j++){
	  print ("M+Rj1 = $M_plus_R[$j][1], M+Rjp11 = $M_plus_R[$j+1][1]\n");
	  if(($PathLength[$j+1] < $MinPathLength) && ($M_plus_R[$j][1] == $M_plus_R[$j+1][1])){ #Choosing the shortest pathlength for a given match rank
	  	$OccamMatch = $j+1; # This if statement is supposed to select the shortest
		                    # pathlength from those matches that all equally have the
				    # same number of clade matches succeeding backwards
		$MinPathLength = $PathLength[$j+1];
		print ("$OccamMatch is OccamMatch ");
	  }
	  if ($M_plus_R[$j][1] != $M_plus_R[$j+1][1]){ #Once the match rank
		last BLK1;                             # increases, we're done
	  }
	}
		print ("\n");
	$mat = $M_plus_R[$OccamMatch][0];
	@genx = split(/\//, $Match[$OccamMatch]); #break InDir1 pathname
	$mat = $genx[$#genx];
	$num = $M_plus_R[$OccamMatch][1];
	print ("mat, num = $mat, $num\n");
	unless (($num == 0) && (($mat eq "Procedures") || ($mat eq "Configuration"))) {
		$#all = -1; # clear out arrays before using
		$#fullfiles = -1; # clear out arrays before using
		$#justfile = -1;
		#print ("$Match[$j]  match we can't open\n");
		#print (" number of array members in match = $#Match\n");
		print ("Occam = $OccamMatch, M+R = $M_plus_R[$OccamMatch][0]\n");
		opendir (DIR, $M_plus_R[$OccamMatch][0]) or die "Unable to open $M_plus_R[$OccamMatch][0]: $!";
		@all = grep { !/^(\.){1,2}|~$|.*db$|^\[|^~/ } readdir (DIR);
		closedir (DIR); 
		for (@all){
			if (!-d ("$M_plus_R[$OccamMatch][0]/$_")){
				push (@fullfiles, "$M_plus_R[$OccamMatch][0]/$_");
				push (@justfile, $_);
			}
		}
		#print ("files to copy:\n");
		for ($l =0; $l <=$#justfile; $l++){
			#print ("$justfile[$l] ");
		}
		print ("\n");
		print ("copy to: $pages[$i][1]\n");

		#  First, loop through $files[$j] and see if it is present in 
		#    $pages[$i][1]
		for $k (0 .. $#justfile){
			$WriteFile = "$pages[$i][1]/$justfile[$k]";
			if (-e ($WriteFile)){ #if it exists, compare 2 - if same 
				              # if do nothing
				if (compare ($fullfiles[$k], #returns 0 if equal
					$WriteFile)){ 
					($dev,$ino,$mode,$nlink,$uid,$gid,$rdev, $size,
     				         $atime,$mtimeWrite,$ctime,$blksize,$blocks)
          				= stat($WriteFile);
				        ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
     				         $atime,$mtimeIn,$ctime,$blksize,$blocks)
          				= stat($fullfiles[$k]);
					if($mtimeIn > $mtimeWrite){ #overwrite
						#if not, do next file for InDir1
						if ($Aflag){ #Create archive directory
							     #and place file in it,
							     #then unlink file
							$Ark = CreateArchive( "$Wdir\/$pages[$i][1]" ); # need to split out
							print ("archive pathname is: $Ark\n");
					 		# Wdirfullname pathnames and add 
					  		#  archive to parent directory of file.
							unless (-e ($Ark)){  # if it already is, dont make it
								unless (mkdir $Ark) {
									die "$Ark not made $!";
								}
							}
							#$mydir = getcwd;
							#	print ("my present dir: $mydir\n");
							unless (-e ("$Ark/$justfile[$k]")){
								move($WriteFile, "$Ark/$justfile[$k]") or die
					 	    		"Move operation failed $!";
					    		}
						}
						unlink $WriteFile;
						rcopy($fullfiles[$k], $WriteFile);
							
					}
				}

			}
			else { # $WriteFile doesnt exist yet - copy it from InDir1
				rcopy($fullfiles[$k], $WriteFile);
			}
		}
		$GotEm = 1;
	}
	}
	unless ($InDir2) {
		next BLK0;
	}
	if ($GotEm && !$Uflag){
		next BLK0;
	}

#NOW Check InDir2 for file
	$#Match = -1; # zero the array before rebuilding
	$#MatchRank = -1; # zero the array before rebuilding
	$#M_plus_R = -1; # zero the array before rebuilding
	$#fullfiles = -1;
	$OccamMatch = 0;
	$#PathLength = -1;
	$#justfile = -1;
	$#geny = -1; # zero the array before rebuilding
	$#genx = -1; # zero the array before rebuilding
	$FindFill = $pages[$i][0];
	find(\&Wanted2, $InDir2); # this loads matching folder names from
	                         #  InDir2 into an array @Match
	@geny = split(/\//, $pages[$i][1]); #break pathname into 
		                          # directory elements
	@geny = reverse @geny;
	for ($m=0; $m <=$#Match; $m++){ # for each match, determine the 
		                   # number of matching directories
				   # with target $pages[$i][1]
		@genx = split(/\//, $Match[$m]); #break InDir1 pathname
		                            # into directory elements
		print ("InDir2 - @genx\n"); #debug line
		@genx = reverse @genx;
		print ("InDir1rev - @genx\n"); #debug line
		print ("LineNoRev - @geny\n"); #debug line
		$PathLength[$m] = $#genx;
		if ($#genx > $#geny) {
			$count = $#geny;
		}
		else {
			$count = $#genx;
		}
		for ($j=0; $j <=$count; $j++){ # determine number of
		                              # generations that match
					      # between $pages and 
					      # $InDir1
			if($genx[$j] eq $geny[$j]){
				$MatchRank[$m] += 1;
			}
			else {
				last;
			}
		}		
	}
	if ($#Match >= 0){
	 $M_plus_R[0] = [@Match];
	 $M_plus_R[1] = [@MatchRank];
	 for $j (0 .. $#Match) { # Transpose matrix to make sorting possible
		print (" Match = $Match[$j]");
		print (" MatchRank = $MatchRank[$j]\n");
		 for $k (0 .. $j -1){ # swap rows for columns
			 ($M_plus_R[$j][$k], $M_plus_R[$k][$j]) =
			 ($M_plus_R[$k][$j], $M_plus_R[$j][$k]);
		 }
	 }
	 print ("Matches before sort - # of matches: $#Match\n");
	 for ($j = 0; $j<=$#Match; $j++){
		 for ($k = 0; $k <=1;$k++){
	  		print ("$M_plus_R[$j][$k] "); 
		}
		print ("\n");
	 }
	 @M_plus_R = sort {$b->[1] <=> $a->[1]} @M_plus_R;
	 print ("Matches after sort: \n");
	 for ($j = 0; $j<=$#Match; $j++){
		 for ($k = 0; $k <=1;$k++){
	  		print ("$M_plus_R[$j][$k] "); 
		}
		print ("\n");
	 }
	$OccamMatch = 0;
  BLK2: for ($j = 0; $j < $#Match; $j++){
	  print ("$j = j \n");
	  print ("$PathLength[$j], $M_plus_R[$j][1]  pl M+R\n");
	  $MinPathLength = $PathLength[0];
	  if(($PathLength[$j+1] < $MinPathLength) && ($M_plus_R[$j][1] == $M_plus_R[$j+1][1])){ # picking 
	  	$OccamMatch = $j+1; # This if statement is supposed to select the shortest
		$MinPathLength = $PathLength[$j+1];
		print("OccamMatch = $OccamMatch\n");
		                    # pathlength from those matches that all equally have the
				    # same number of clade matches succeeding backwards
	  }
	  if ($M_plus_R[$j][1] != $M_plus_R[$j+1][1]){
		last BLK2;
	  }
	}	  
	$mat = $M_plus_R[$OccamMatch][0];
	$mat =~ /\w*$/;
	$num = $M_plus_R[$OccamMatch][1];
	print ("mat, num = $mat, $num\n");
	unless (($num == 0) && (($mat eq "Procedures") || ($mat eq "Configuration"))) {
		$#all = -1; # clear out arrays before using
		$#fullfiles = -1; # clear out arrays before using
		$#justfile = -1; # clear out arrays before using
		print ("Occam2 = $OccamMatch, M+R = $M_plus_R[$OccamMatch][0]\n");
		opendir (DIR, $M_plus_R[$OccamMatch][0]) or die "Unable to open $M_plus_R[$OccamMatch][0]: $!";
		print ("just opened $M_plus_R[$OccamMatch][0] in InDir2\n");
		@all = grep { !/^(\.){1,2}|~$|.*db$|^\[|^~/ } readdir (DIR);
		closedir (DIR); 
		for (@all){
			if (!-d ("$M_plus_R[$OccamMatch][0]/$_")){
				push (@fullfiles, "$M_plus_R[$OccamMatch][0]/$_");
				push (@justfile, $_);
			}
		}
		print ("files to copy from InDir2:\n");
		for ($l =0; $l <=$#justfile; $l++){
			print ("$justfile[$l] ");
		}
		print ("\n");
		print ("copy to: $pages[$i][1]\n");
		#  First, loop through $justfile[$j] and see if it is present in 
		#    $pages[$i][1]
		for $k (0 .. $#justfile){
			$WriteFile = "$pages[$i][1]/$justfile[$k]";
			if (-e ($WriteFile)){ #if it is, compare 2 - if same 
				              # if do nothing
				print ("Yes, $WriteFile exists\n");
				if (compare ($fullfiles[$k], #returns 0 if equal
					$WriteFile)){ 
						if ($Uflag){ # copy over file from InDir2 regardless of age
							     #  difference
							if ($Aflag){ #Create archive directory
							     #and place file in it,
							     #then erase file
								$Ark = CreateArchive("$Wdir\/$pages[$i][1]" ); # need to split out
								print ("archive pathname is: $Ark\n");
					 			# Wdirfullname pathnames and add 
					  			#  archive to parent directory of file.
								unless (-e ($Ark)){  # if it already exists, don't make it
									unless (mkdir $Ark) {
										die "$Ark not made $!";
									}
								}
							} 
							#if not, do next file for InDir2
							if ($Aflag){ #Move file to archive
								#then unlink it
								unless (-e ("$Ark/$justfile[$j]")){
									move("$WriteFile", "$Ark/$justfile[$j]") or die
					 	    	 		"Move operation failed $!";
					    			}
						 	}
							unlink $WriteFile;
							rcopy($fullfiles[$k], $WriteFile);
						}
						else { # No $Uflag - compare file ages - keep/take newest
							if ($Aflag){ #Create archive directory
							     #and place file in it,
							     #then unlink file
								$Ark = CreateArchive( "$Wdir\/$pages[$i][1]" ); # need to split out
								print ("archive pathname is: $Ark\n");
					 			# Wdirfullname pathnames and add 
					  			#  archive to parent directory of file.
								unless (-e ($Ark)){  # if it already exists, don't make it
									unless (mkdir $Ark) {
										die "$Ark not made $!";
									}
								}
							} 						
							($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,
     				    			$size,$atime,$mtimeWrite,$ctime,$blksize,$blocks)
          						= stat($WriteFile);
				   			($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
     				   			 $atime,$mtimeIn,$ctime,$blksize,$blocks)
          						= stat($fullfiles[$k]);
							if($mtimeIn > $mtimeWrite){ #overwrite
								#if not, do next file for InDir2
								if ($Aflag){ #Move file to archive
									#then unlink it
									unless (-e ("$Ark/$jusfile[$j]")){
										move("$WriteFile", "$Ark/$justfile[$j]") or die
					 	    		 		"Move operation failed $!";
					    				}
						 		}
								unlink $WriteFile;
								rcopy($fullfiles[$k], $WriteFile);
							}

						}
				}
			}
			else { #Writefile doesn't exist yet - write it
				#print ("No, $WriteFile doesnt exist\n");
				rcopy($fullfiles[$k], $WriteFile);
			}
		}
	}
  	}
}
}
sub WipIt {
	my ($d, $path)  = @_; # $path is InDir from direct.pl call
	               # $d is recursion depth 
	my ($j, $k, $l);
	my @files;
	my $Pass;
	print ("path  = $path, d = $d\n");
	opendir (DIR, $path)
		or die "Unable to open $path: $!";
	@files = grep { !/^(\.){1,2}|~$|.*db$|^\[|^~/ } readdir (DIR);#my try	
	closedir (DIR); # This call fills in files from whatever subdir we
	                #  are presently in inside InDir
	#print ("files  = @files\n");
	$#fullfiles = -1;
	@fullfiles = map { $path . '\\' . $_ } @files;  #full path name
	#print ("fullfiles read in = @fullfiles\n");
	for ($j = 0; $j <= $#files; $j++) {
		#print ("j = $j Total #j = $#files\n");
		if (-d "$fullfiles[$j]") {
			#print ("fullfiles dir = $fullfiles[$j]\n");
			# Root directories in InDir are not written to $WDir 
			#  in WipIt because
			#  there is no parent to show where they go.  Root
			#  directories are only containers of transferrable
			#  similar to a wharf at a dock as opposed to a barge.
			# There are a InDir1 and WDir1 in 
			# DocManager/Sandbox as a test case to see
			# First: find like directories in WDir
			# print ("yep $fullfiles[$j] is a directory\n");
			if ($d) { # no need to do the matching if in the root 
			 	  # folder of InDir
				  #print ("fullfiles before split = $fullfiles[$j]\n");
				@FFSplit = split(/\\/, $fullfiles[$j]);
				#print ("FFSplit = $FFSplit[0] $FFSplit[1] $FFSplit[2]\n");
				find (\&Wanted, $WriteDir); # This fills in an 
				         # array with matching subdirs found in
					 # $WriteDir for checking for best fit
					 #print ("Matchd = @Matchd\n");	
				for ($k = 0; $k <= $#Matchd; $k++){ #This is 
				     # the loop where we do the checking and 
				     # writing
				     #  Not used: 
				     #    @WMatchSplit = split("/", $Matchd[$k]);
					$_ = "$Matchd[$k]/$files[$j]";
					if(! -e){ # go ahead and copy it to Wdir
						rcopy($fullfiles[$j],
						 "$Matchd[$k]/$files[$j]");
					 }
				 }
				 $#Matchd = -1; # zero out @Matchd array for 
				                #  next search
			 }
			$d++;
			#print ("depth = $d\n");
			$LookFor = $fullfiles[$j];
			&WipIt($d, $LookFor); # recurse   
				# 
		}
		else {  # this is a file - find all instances in WDir and 
			# replace and archive (unless -n) if not identical
			#print ("nope $files[$j] is not a dir\n");
		  $LookFor = $files[$j];
		  find (\&Wanted3, $WriteDir); #Now @Matchf has the pathnames of 
		                        # matching files in Wdir to the file in 
					# InDir we want to replace it with.  
					# If it is the same file, do nothing.
					# If it is different, archive the 
					# original and replace.
		#print ("Matchf = @Matchf \n");
		  for ($k = 0; $k <= $#Matchf; $k++){ #This is the loop where we 
			#do the checking and writing
			#print ("k = $k\n");
			print ("Matchf =$Matchf[$k], k = $k\n");
			print ("fullfiles = $fullfiles[$j], j = $j\n");
			if (compare ("$Matchf[$k]", 
				"$fullfiles[$j]")){ #returns 0 if files 
				                            # are equal - 
						  #  don't copy or archive
				#print ("NoArchive = $NoArchive\n");
				if($NoArchive) {
				#print ("$NoArchive is\n");
					#delete file 
					unlink "$Matchf[$k]";
				}
				else {
					#print("$NoArchive is 0?\n");
					print ("Matchf =$Matchf[$k], k = $k\n");
					#Create archive folder
					$Pass = $Matchf[$k];
					print ("pass = $Pass\n");
					$Ark = CreateArchive( "$Wdir\/$pages[$i][1]" ); # need to split out
					print ("archive pathname is: $Ark\n");
					  # Wdirfullname pathnames and add 
					  #  archive to parent directory of file.
					unless (mkdir $Ark) {
						die "$Ark not made $!";
					}
					#$mydir = getcwd;
					print ("my present dir: $mydir\n");
					move("$Matchf[$k]", "$Ark/$files[$j]") or die
					 "Move operation failed $!";
					unlink "$Matchf[$k]";
				}
				rcopy("$fullfiles[$j]",
				 "$Matchf[$k]");
			}
			$#Matchf = -1; # zero out @Matchf array for next search
			#print ("Matchf after zeroing = @Matchf\n");
		}
	     }
	}
	#print ("Finished a WipIt goround\n");
}
sub Wanted
{
	#match the parent directory of the InFile directory with $_
	if( $_ eq $FFSplit[$#FFSplit -1] ){
		push (@Matchd, $File::Find::name); # save full WriteDir pathname
		                                   # that matches InDir parent
						   # folder of InDir folder 
						   # being operated on
	}
}
sub Wanted2
{
	if($_ eq $FindFill){
		if (-d ){
			#print("Found $FindFill\n");
			$mydir= getcwd;
			#print ("Where we're at: $mydir\n");
			#print("Found filefindname: $File::Find::name\n");
			push (@Match, $File::Find::name); # save full pathname of
			#print ("found dir\n");
		}
		                        #  matching InDir1/InDir2 folder
	}
}
sub Wanted3
{
	#print ("looking for $_ LookFor= $LookFor\n");
	#match the parent directory of the InFile directory with $_
	if($_ eq $LookFor ){
		#print ("found it $_\n");
		push (@Matchf, $File::Find::name); # save full WriteDir pathname
		                                   # that matches InDir parent
						   # folder of InDir folder 
						   # being operated on
						   #print ("in W3 Matchf = @Matchf\n");
	}
}

sub CreateArchive
{
	# Takes passed argument (full pathname of to be saved file in
	#   WDir, splits it, and creates an archive directory in the WDir 
	#   folder the saved file is in.
	my $pname = $_[0];
	print ("pname as passed = $pname\n");
	my @gname = split(/\//, $pname);
	print ("pname after split = @gname\n");
	my $Arc;
	$time = TimeStamp();
	my $ArcTime = "Archive$time";
	$#gname -=1; # remove last element from pathname (file itself)
	$Arc =join ("/", (@gname, $ArcTime)); 
	print ("Arc pathname is $Arc\n");
	return $Arc;
}
sub TimeStamp
{
my $TimeStamp;
($MIN, $HOUR, $DAY, $MONTH, $YEAR) = (localtime)[1,2,3,4,5];
$YEAR += 1900;
$MONTH += 1;
if ($DAY < 10){
	$DAY = "0$DAY";
}
if ($MONTH < 10){
	$MONTH = "0$MONTH";
}
if ($MIN < 10){
	$MIN = "0$MIN";
}
if ($HOUR < 10) {
	$HOUR = "0$HOUR";
}
$TimeStamp = "$YEAR$MONTH$DAY\_$HOUR$MIN";
return $TimeStamp;
}

#####################################
# COPYING INBOX FILES TO PROPER LOCATION
#####################################

sub InboxFileCopy{

	foreach $f (@GoodInboxFiles){
		for $i (0 .. $#pages) {
			if($f  eq $pages[$i][4]){
				#rename the old file filenameDATE.xxx and place it in Folder/obsolete
				($fname, $fextension) = split(/\./,"$f");
				move("$pages[$i][2]/$f","$pages[$i][2]/obsolete/$fname$Ryear$Rmonth$day.$fextension");

				#copy the file into new location
				copy("$InboxDirectory/$f",$pages[$i][2]);
				#print "copy from: $InboxDirectory/$f\n";
				#print "copy to: $pages[$i][2]\n";
				#getc();
			}
		}
	}
}

#####################################
# Find each folder's index.htm and report if one is missing
#####################################

sub FindIndex_html{
	open(ANOMALIES,">>$AnomaliesLocation") || die ("Couldn't open $AnomaliesLocation\n");
	print ANOMALIES "\n\n";

	$previous = "hello";
	for $i (0 .. $#pages) {
		unless(-e $pages[$i][3]){ #-e checks that the file exists
			#print "\nnot exist: $pages[$i][3]";
			#getc();
			#
			unless($previous eq $pages[$i][3]){ #This keeps duplicates from appearing on the list.
				print ANOMALIES "Default Index.htm created: $pages[$i][3]\n";
				#need to search folder for a image? then pass it to the next function if so
				&Create_Index;
				}
			$previous = $pages[$i][3];





		}


	}

	close(ANOMALIES);
}	



################################################
#CREATES A INDEX.HTM IF NONE EXISTS IN THE FOLDER
################################################
sub Create_Index
{
	open(WEBSITE,">$pages[$i][2]/index.htm") || die ("oops can't create file");


	if (-e "$pages[$i][2]/$pages[$i][4]"){
		($fname,$fext) = split(/\./, $pages[$i][4]);
		$fullpicturename = $pages[$i][4];
	}
	else{
		#use default
		copy("./DefaultInst.png","$pages[$i][2]/DefaultInst.png");
		$fullpicturename = "DefaultInst.png";
		$fname = "DefaultPicture";
	}

	print WEBSITE "<html>\n<head>\n<title>";
	print WEBSITE "$fname";
	print WEBSITE "</title>\n</head>\n";
	print WEBSITE "<body>\n<div>\n";
	print WEBSITE "<img src=\"./$fullpicturename\" alt=\"\" usemap=\"\#$fname\" style=\"border-style:none\" />\n";
	print WEBSITE "</div>\n<div>\n";
	print WEBSITE "<map id=\"$fname\" name=\"$fname\">\n";
	#need some math to calculate number of ../../../s
	$numb_spaces = $pages[$i][1];
	$dotdotslashes = "";
	for (0 .. $numb_spaces){
		$dotdotslashes = $dotdotslashes . "../";
	}
	$TAoutline = "TAoutline.htm";
	$OtherOutline = "INTRoutline.htm";
	print WEBSITE "<area shape=\"rect\" alt=\"\" coords=\"2,3,88,41\" href=\"$dotdotslashes$TAoutline\" target=\"_blank\" title=\"\" />\n";
	print WEBSITE "<area shape=\"rect\" alt=\"\" coords=\"89,3,175,41\" href=\"$dotdotslashes$OtherOutline\" target=\"_blank\" title=\"\" />\n";


	print WEBSITE "<area shape=\"rect\" alt=\"Click to go back\" coords=\"0,0,9000,9000\" href=\"../index.htm\" title=\"\" />\n";
	print WEBSITE "</map>\n</div>\n</body>\n</html>\n";

	close(WEBSITE);
	#print "Created an index.htm for $pages[$i][4] in the \n$pages[$i][2] folder\n";

}



################################################
#PUT OUTLINE INTO HTML PAGE WITH RELATIVE LINKS
################################################
sub CreateWebOutline{

my $fountsize = 1;

open(WEBOUTLINE,">$WriteDir/TAoutline.htm") || die ("outline.htm not created");
($day, $month, $year) = (localtime)[3,4,5];


print WEBOUTLINE "<html>\n<head>\n\t<title>";
print WEBOUTLINE "TA OUTLINE $year $month $day";
print WEBOUTLINE "</title>\n</head>\n";
print WEBOUTLINE "<body>";

$last_folder_name = "junk";

for $i (0 .. $#pages){

	if($pages[$i][1] < 4){
		$fontsize = 6-$pages[$i][1];
	}
	else{$fontsize=3;}

#Don't want to display the childen of the Procedures and Configs Folders
	if($pages[$i][2] =~ /Procedures\//) {
		if($pages[$i][2] =~ /Procedures\/$/)
		{	$flagout = 0;
		}else{$flagout = 1;}	
	}
	if($pages[$i][2] =~ /Configurations\//)
	{
		if($pages[$i][2] =~ /Configurations\/$/)
		{	$flagout = 0;
		}else{$flagout = 1;}	
	}
#Don't want to display CloseUp_ pictures on the outline.htm
	if($pages[$i][0] =~ /CloseUp_/)
	{
		$flagout = 1;	
	}
#Don't want to display Detail pictures on the outline.htm	
	if($pages[$i][0] =~ /Detail/)
	{
			$flagout = 1;	
	}
#Don't want to display 110949 pictures on the outline.htm	
	if($pages[$i][0] =~ /110949/)
	{
			$flagout = 1;	
	}

	unless( ($last_folder_name eq $pages[$i][0]) or ($flagout eq 1) ){

		print WEBOUTLINE "\n<font size=\"",$fontsize,"\">\n";
		print WEBOUTLINE "\n<font size=\"4\">\n<br>\n";
		foreach my $j (0..$pages[$i][1])
			{print WEBOUTLINE "&nbsp&nbsp&nbsp&nbsp";}
		print WEBOUTLINE "</font>";	

		$templi = substr($pages[$i][3],length($WriteDir));
		print WEBOUTLINE "<a href=\".$templi\">$pages[$i][0]</a>\n";
		print WEBOUTLINE "</font>";

	}
	$last_folder_name = $pages[$i][0];
	$flagout = 0;
}

print WEBOUTLINE "</body>\n</html>\n";

close(WEBOUTLINE);

}
