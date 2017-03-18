#!/usr/bin/perl
# usage: makeout.pl (InDir_path, Rdepth)
#  This routine takes a directory structure (InDir) and makes an
#   outline of it - looking for index.htm files in each directory and
#   if present, and if there's an imagemap tag in it
#   (e.g. <img src="TAMast.png"), it adds a : and the TAMast.png info to the
#   outline that is being created.  The outline is given the name:
#   Outyyyymmddhhmm.txt.  If there isn't an index with an imagemap tag in it, 
#   the outline is built so that lists of files in the directory(ies) are 
#   written so that each file has its own line and only directories have 
#   enumeration.   Presently, lists (as opposed to imagemaps) have the syntax:
#   2. FolderName: filename,
#      filename2, ...
#      filenamelast;
#  Rdepth is the recursion depth - further calls to makeout.pl from the routine
#   I am considering changing the : to a - for lists, to differentiate them 
#   more completly from imagemap lines - not sure yet. The only downside that
#   I can figure so far is that it loses downward compatability w/ old outlines
#
#   Directly below I am dropping in a routine from the file RecursiveProcess.pl
#   process_files ($base_path);

# Accepts one argument: the full path to a directory.
# Returns: an Outyyyymmddhhmm.txt outline
#  ROUTINE PROCESS
#  I. Open up the directory
#   A. For each entry, determine type (existing index.htm tells):
#    1. Folders - determine enumerator
#     a. Folder of lists
#      I. create sublist striking out files not to be listed, including:
#       index.htm, index.hml, .*, ~*
#      II. Check that list lengths are not exceeded - issue warning 
#     b. Folder of imagemap
#      I. Check index.htm to determine image file (follows : in line)
#      II. Otherwise look for sole image in directory.
#     c. Folder undetermined
#      I. print dir/filenames in a clump for examination
#      II. Default, treat as a list folder
#    2. Files
#     a. list file
#      I. Print list file on a single line of the new outline, followed by a ,
#      II. Last one is followed by a ;
#     b. imagemap files - 
#      I. 2 files inside the imagemap folder are imagemap files:
#       A. index.htm
#       B. image file (preferentially indicated by a line in index.htm
#     c. ignored files - e.g. .*, ~* - files not printed in outline
#     d. archived files - in archive folders
#     e. undetermined files -
#      I. If in list folders, go ahead and list them
#      II. If in image map folders, ignore them for outlines
#
#  Next - which info is required in an array Outline[$line_number][$i]
#54   $i = 0 - number of spaces before enumerator - determines enumerator class
#55    = 1 - enumerator, including correct class (determined from [0]) and 
#56          sequence number and whether it is composed of a couple of 
#57          blanks, in case of lists)
#58      2 - file or directory name ( not full path name)
#59      3 - full path name
#60      4 - image name
#61      5 - list   (Comma delimiter)
my $slast; # number of spaces before enumeration for the previous line
my @Romans; # Array that has the sequence of Roman numerals in it
my @Caps; # Array that has the sequence of Capital letters in it
my @Lower; # Array that has the sequence of lower-case letters in it
my @Nums; # Array that has the sequence of numbers in it
@Romans = ('I','II','III','IV','V','VI','VII','VIII','IX','X','XI','XII', 
	'XIII','XIV','XV','XVI','XVII','XVIII','XIX','XX','XXI','XXII',
	'XXIII','XXIV','XXV','XXVI','XXVII', 'XXVIII','XXIX','XXX','XXXI',
	'XXXII','XXXIII','XXXIV','XXXV','XXXVI','XXXVII','XXXVIII',
	'XXXIX','XL','XLI','XLII','XLIII','XLIV','XLV','XLVI','XLVII',
	'XLVIII','XLIX','L','LI','LII','LIII','LIV','LV','LVI','LVII',
	'LVIII','LIX','LX','LXI','LXII','LXIII','LXIV','LXV','LXVI',
	'LXVII','LXVIII','LXIX');
my $maxRomans = $#Romans;
@Caps = ('A','B','C','D','E','F','G','H','I','J','K','L', 
	'M','N','O','P','Q','R','S','T','U','V','W','X', 
	'Y','Z','AA','BB','CC','DD','EE','FF','GG','HH','II','JJ', 
	'KK','LL','MM','NN','OO','PP','QQ','RR','SS','TT', 
	'UU','VV','WW','XX','YY','ZZ');
my $maxCaps = $#Caps;
@Lower = ('a','b','c','d','e','f','g','h','i','j','k','l', 
         'm','n','o','p','q','r','s','t','u','v','w','x', 
         'y','z','aa','bb','cc','dd','ee','ff','gg','hh','ii', 
         'jj','kk','ll','mm','nn','oo','pp','qq','rr','ss','tt', 
         'uu','vv','ww','xx','yy','zz');
my $maxLowers = $#Lower;
@Caps = ('A','B','C','D','E','F','G','H','I','J','K','L', 
	'M','N','O','P','Q','R','S','T','U','V','W','X', 
	'Y','Z','AA','BB','CC','DD','EE','FF','GG','HH','II','JJ', 
	'KK','LL','MM','NN','OO','PP','QQ','RR','SS','TT', 
	'UU','VV','WW','XX','YY','ZZ');
my $maxCaps = $#Caps;
@Lower = ('a','b','c','d','e','f','g','h','i','j','k','l', 
         'm','n','o','p','q','r','s','t','u','v','w','x', 
         'y','z','aa','bb','cc','dd','ee','ff','gg','hh','ii', 
         'jj','kk','ll','mm','nn','oo','pp','qq','rr','ss','tt', 
         'uu','vv','ww','xx','yy','zz');
my $maxLowers = $#Lower;
@Nums = ('1', '2', '3', '4', '5', '6','7', '8','9', '10', '11', '12',
	'13', '14', '15', '16', '13', '14', '15', '16', '17', '18', '19', '20',
	'21', '22', '23', '24', '25', '26', '27', '28', '29', '30', '31', '32',
	'33', '34', '35', '36', '37', '38', '39', '40', '41', '42', '43', '44',
	'45', '46', '47', '48', '49', '50', '51', '52', '53', '54', '55', '56',
	'57', '58', '59', '60', '61', '62', '63', '64', '65', '66', '67', '68');
my $maxNumbers = $#Nums;
my $maxColumn = 40;
my @Column = (0) x $maxColumn; 
my @Enums;
$Enums[0] = [@Romans];
$Enums[1] = [@Caps];
$Enums[2] = [@Nums];
$Enums[3] = [@Lower];
my @DirSpacesList;
$A = $ARGV[0];
$NoFiles = $ARGV[1];
print ("$NoFiles\n");
$DirNumber = 0; # increments once for each directory reported
$LineNumber = 0; # increments once for each file reported, for each line of
#                  the outline
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
$Outstring = "OUT$YEAR$MONTH$DAY" . "_$HOUR$MIN.txt"; #outline file
open (OUT, ">$Outstring") or die ("Cannot open $Outstring");
$D = 0; #Set recursion depth before first line 
#print "This is first directory: $A\n";
&makeout($A, $D);
sub makeout {
    my ($path, $depth) = @_;
    my @fullfiles;
    my @files;
    # $depth starts out at 0 for the first call and increments by 1 each
    # time &makeout is called from itself.  

    # Open the directory.
    opendir (DIR, $path)
        or die "Unable to open $path: $!";

    # Read in the files.
    # You will not generally want to process the '.' and '..' files,
    # so we will use grep() to take them out.
    # See any basic Unix filesystem tutorial for an explanation of them.
    #my @files = grep { !/^(\.|~){1,2}/ } readdir (DIR);#worked ok, I think
    my @files = grep { !/^(\.){1,2}|~$|.*db$|^\[/ } readdir (DIR);#my try
    #my @files = grep { !/^\.{1,2}$/ } readdir (DIR);

    # Close the directory.
    closedir (DIR);

    # At this point you will have a list of filenames
    #  without full paths ('filename' rather than
    #  '/home/count0/filename', for example)
    #  We'll also make a version now with the full filename, including
    #   the pathname using map() to tack it on.
    #  (note that this could also be chained with the grep
    #   mentioned above, during the readdir() )
    @fullfiles = map { $path . '\\' . $_ } @files;
    my $FileDirCount = 0;
    for (@fullfiles) {
	    # for each array member of @file, there will be an outline line 
	    # written of the form:
	    # I. FirstDir:ImageFile1.png
	    #  A. 2ndDir:ImageFile2.png
	    #   1. ListDir1 
	    #    a. firstfile,
	    #    b. lastfile;
	    #       NOTE Directories have children, files don't
	$LineNumber += 1;
	$FileDirCount += 1;
	$Outline[$LineNumber][0] = $depth;  # fulfilling line 54 task
	#
	# If the file is a directory, we need to do the following:
	# 1. Determine the enumerator for the entry
	# 2. Determine whether it is an imagemap or list directory
	#  a. Look for index.htm file in files read from directory
	#   I. read it and look for imagemap tag or list tags
	#  b. If no index.htm file, look for single .png or .jpg file
	#  c. keep track of condition of directory:
	#   I. Yes or No index.htm
	#   II. Yes or No identifiable image
	#   III. Yes or No - empty directory
	if (-d $_) { # start by only adding enumerators to directories
		$NextDir = $_;
		if ($LineNumber == 1) {
			$slast = -1;
			$Column[0] = 1; #Initialize
			$s = 0;
			$DirSpacesList[0] = 0;
		}
		else {
			$DirSpacesList[$DirNumber] = $depth;
			$slast = $DirSpacesList[$DirNumber-1];
			$s = $DirSpacesList[$DirNumber];
			$DirNumber += 1;
		}
		if ($slast == $s){ # this line and previous lines are siblings	
        		$Column[$s] += 1;
			# I suspect I will have to do some more work here so I get 
			#  siblings identified correctly. Presently - only 
			#  neighboring siblings get called - maybe further down
			#  (elseif($s < $slast) will catch it
			
		}
		elsif ($s == ($slast + 1)){ #present line is a child of 
			#previous line
			$Column[$s] = 1;
		}
		elsif ($s < $slast){ #if true, then we have reached the end of 
				     #	at least one cohort line (family)
			             # and must zero out higher order sequence 
				     # counters in @Column
				     #print ("C array_count = $array_count, 
				     # s = $s, slast = $slast\n");	
			$Column[$s] +=1;
			for ($k = $s+1; $k<($maxColumn + 1); $k++){
				$Column[$k] = 0;
			}
		}
		#	**** 2015 07 28 1616 - next add code to make enumerator
		#	for directories to start with 
	 $E = $Enums[$s % 4][$Column[$s]-1];
	 #Print directory 
	 $jnk = (' ' x $depth) . $E . ('. ') . $files[$FileDirCount-1];
	 #$Column[$depth] +=1;
	 print OUT "$jnk\n";
  	    # Here is where we recurse.
            # This makes a new call to process_files()
            # using a new directory we just found.
            makeout ($NextDir, $depth+1);

        # If it isn't a directory, lets just do some
        # processing on it.
        } else { # these are files 
		$jnk = (' ' x ($depth+1)) . $files[$FileDirCount-1];
		if ($NoFiles){
			print ("NoFiles = $NoFiles\n");
			print OUT "$jnk\n";
		}
            # Do whatever you want here =)
	    # 1. identify certain files to examine
	    # 2. identify certain files to ignore 
	    # 3. calculating filename depth and increment rank (@Column
	    # 4. reporting
	    #  a. write enumerated outline
	    #  b. directory structure
	    #   I. missing index files
	    #    A. writing reports listing missing
	    #   II. missing picture files
	    #    A. writing reports listing missing
	    #   III. missing directory structure
	    # 5. Do it - do it right!
        }
#	if ($LineNumber < 176 && $LineNumber > 162) {
	#	print OUT ("S, SLAST, Column 0, 1, 2 ,3,4\n");
	#	print OUT ("$s, $slast, $Column[0], $Column[1], $Column[2], $Column[3], $Column[4]\n"); 
	#}
    }
}
