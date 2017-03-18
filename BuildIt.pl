#!/usr/bin/perl
# usage  BuildIt.pl WriteDir
use File::Slurp;
use File::Path;
use Cwd;
my $path = $ARGV[0]; # $path is the subdir of WriteDir presently being worked on
print ("path = $path\n"); #Note: presently the program has been tested residing
                          # in the directory containing WriteDir
my $time = &TimeStamp();
my $Outstring = "Rep_$time.txt"; #Report file
open(REP,">>$Outstring") || die ("Couldn't open $Outstring\n");
print REP "Date: $Outstring\n";
print REP "WriteDir: $path\n";
&BuildWeb ($path);

sub BuildWeb
{
#
#This routine takes a directory structure (e.g. WriteDir) and checks each 
# subdirectory for:
# 1) whether an index.htm file exists, 
# 2) type of index.htm file (image or list), 
# 3) whether the index.htm file adequately describes the subdir it is in, 
# 4) and fixes it if needed, 
# 5) builds the appropriate index.htm, and subdirectory, if missing.
#
#
# Task 1) use readdir recursively to collect subdirs and files throughout
#   the tree
# Task 2) for each dir, 
#   A. If present, Identify index.htm
#     1. Determine type - 
#      a. image
#       I. Fix and/or report any mistakes 
#        A. super long linknames - eg c:\backup\USArray\...\image.png change
#         to ./image.png
#        B. unmatched image.png names (within index.htm vs in the dir
#        C. unmatched subdirs - not present in image map links
#       II. rewrite index.htm into directory 
#      b. list
#       I. Fix and/or report any mistakes 
#        A. unmatched file names in index.htm not present in the dir
#        B. unmatched files not present in index.htm 
#        C. unmatched subdirs not present in index.htm
#        D. unmatched subdirs listed in index.htm not present in dir
#       II. rewrite index.htm
#      c. no content
#       1. verify content still missing
#       2. if content present, create appropriate index.htm
#        a. list unless one and only one image and no subdirs
#
#   B. if no index.htm build apropriate index.htm
#    1. Determine type
#     A. Image -
#      I. conditions: (1 &only 1) image and no subdirs present.
#      II. build index.htm
#     B. List - 
#      I. conditions: (files present, but doen't meet Image condition
#      II. buid index.htm
#     C. No content - no files or subdirs present.
#
my $where = @_[0];
my $j;
my $i;
my $image_count = 0;
my @image;
my @contents;
my $Index_ok = 0;
my $got_it =0;
my @fulldirs;
my @fullfiles;
my $justfilename;
my @splitfile;
my @contents;
my @fullcontents;
my $AlreadyIndex = 0;
#print ("where = $where\n");
$#fulldirs = -1;
$#fullfiles = -1;
$#contents = -1;
$#fullcontents = -1;
opendir (DIR, $where) or die "Unable to open $where: $!";
@contents = grep { !/^(\.){1,2}|~$|.*db$|^\[|^~/ } readdir (DIR);	
closedir (DIR);
@fullcontents = map { $where . '\\' . $_ } @contents;  #full path name
for ($j = 0; $j <=$#contents; $j++){
	print ("contents = $fullcontents[$j]\n");
	if (-d "$fullcontents[$j]"){
		push (@fulldirs, $fullcontents[$j]);
	}
	else {
		#print ("contents: $_\n");
		push (@fullfiles, $fullcontents[$j]);
	}
}
for ($j=0; $j <=$#fullfiles; $j++){
	#print ("in $where fullfiles = $fullfiles[$j]\n");
	@splitfile = split(/\\/, $fullfiles[$j]);
	$justfilename = $splitfile[$#splitfile];
	if ($justfilename eq "index.htm") { 
	        $got_it = 1;	
		$AlreadyIndex = $j;
		#print ("found index in $fullfiles[$j]\n");
	}
	if ($fullfiles[$j]=~ /\.png|\.jpg|\.PNG|\.JPG/){ #looking for image file
		#print ("In $where, image = $fullfiles[$j]\n");
		$image[$image_count] = $fullfiles[$j];

		$image_count += 1;
	}
}
if ($got_it){ #take care of index.htm
	#print ("got it where = $where\n");
	$Index_ok = &CheckIndex(\$where, \$fullfiles[$AlreadyIndex], \@fulldirs, \@fullfiles, \@image); #  index.htm syntax and links ok?
	unless ($Index_ok){ #if index.htm is not ok, archive and rebuild
		print REP ("Index not ok for $where\n")
		#&ArchiveIndex
		#&MakeIndex;
	}
}
else{
	#print ("no got it where = $where\n");
	&MakeIndex(\$where, \@fullfiles, \@fulldirs, \@image) ; # make an index from files in directory (list or image,
	            # depending on image count
}
for ($i; $i <=$#fulldirs; $i++){
#	print ("next BuildWeb call w/ $fulldirs[$i]\n");
	&BuildWeb($fulldirs[$i]);
}
}
#
#CheckIndex - subroutine to check that the index.htm file is correct and/or
#    make some necessary corrections, including building linked, but non-
#     existent subdirectories
# I. Determine index.htm type
#  A. Image
#   1. verify image exists
#   2. verify linked directories exist
#   3. verify links exist for directories in present directory
#   4. make editing changes necessary for compatibility with Boutelle image
#       map results
#  B. List
#   1. verify existing files and subdirectories are included in index.htm
#   2. verify listed files and subdirectories in index.htm exist in present dir
#&CheckIndex(\$where, \$fullfiles[$AlreadyIndex], \@fulldirs, \@fullfiles, \@image);   
sub CheckIndex 
{
#
my $at = shift;	# $where passed as a reference
my $im_at = $$at; #dereferenced
my $indexfref = shift;        #passed references into CheckIndex to get the whole
my $dir_ref = shift;  # subdir array inside subroutine since we need to
my @FDirs = @$dir_ref;# check if they are present in the index.htm file
my $indexf = $$indexfref; #  Here is how you unreference a reference inside
                           #   a subroutine (prepend w/ a $
my $ffles = shift; # pass reference to subroutine files array
my @fffs = @$ffles;  # @fffs is array of files in present directory where index.htm was pulled from
my $image2 = shift;
my @image = @$image2;
my @lines;
my ($j, $k);
my $ll;
my @fname;
my $ExtraDir;
my $ExtraFile;
my $LinkOk;
my $image_ok=0;
my $img;
my @img;
my @tmp;
my @jnk;
my @link;
my @dir;
my $success;
my $mydir;
my @lFiles;
my @lFolders;
my @slFold;
my @LLf;
my @Diir;
my $cnt;
my @LinkDirs;
my @title = split(/\\/, $indexf); #splitting out last subdir for title name
my $title= @title[$#title-1];
#print ("got into CheckIndex, indexf = $indexf\n");
#print ("dir for title should be: $title\n");
#Open the index.htm 
@lines = read_file ($indexf);
#print ("lines[0] in BuildWeb before switch: $lines[0]\n");
#open (IDEX, "<$indx") || die "index.htm FILE NOT FOUND $indx\n"; #alternate
if ($lines[0] =~/xml/){ #  this is an image folder
	$lines[0] = "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n";
	$lines[1] = "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"DTD/xhtml1-strict.dtd\">\n";
	$lines[2] = "<html xmlns=\"http://www.w3.org/1999/xhtm\" xml:lang=\"e\" lang=\"en\">\n";
	$lines[3] = "<head>\n";
	$lines[4] = "<title>$title</title>\n";
	$lines[5] = "</head>\n";
	$lines[6] = "<body>\n";
	$lines[7] = "<div>\n";
	#print ("lines[8] = $lines[8]\n");
	if ($lines[8] =~/img src="(.*)" alt(.*)>/){
		$title = $1;
		@title = split(/\\/, $title);
		$title = @title[$#title];
		for ($j = 0; $j<= $image[$#image]; $j++){
			@img = split(/\\/, $image[$j]);
		        $img = $img[$#img];	
			#print("back slash image = $img\n");
			#print("title = $title\n");
			if ($title eq $img){
				$image_ok = 1;
				last;
			}
		}
		if (!$image_ok){
			print REP ("Image $title missing in $im_at\n");
		}	
		$lines[8] = "<img src=\"$title\" alt$2>\n";
	}
	else { # this index.htm is out of order and we'll write it as a list page
		$image_ok = 0; #something is wrong with this index.htm
		#print ("index at $im_at seems out of order for line 9\n");
	}
	$lines[9] = "</div>\n";
	$lines[10] = "<div>\n";
	#print ("title before: $title\n");
	$title =~ s/\..*//; # strip suffix off title name (img.png => img)
	#print ("title after: $title\n");
	$lines[11] = "<map id=\"$title\" name=\"$title\">\n";
	$k = 0;
  LINK:	for ($j = 12; $j <=112; $j++){ #save the subdirectory names linked to
		if ($lines[$j] =~/coords=.*href=\"(.*)\" title/){
			$LinkDirs[$j-12] = $1; #saved subdirectory links
			$k += 1; # counter to keep track of # of area shape lines
		}
		else{
			last LINK;
		}
	} # Note 100 is the max number of links this program will check
	if($#LinkDirs){ #yes there are some links to subdirectories
	GotDir:	for ($j = 0; $j <= $#LinkDirs; $j++) {#check for the existence of 1) subdirs
		                                      #  matching links
			#print ("$LinkDirs[$j] linkdirs\n");
			@tmp = split (/\//, $LinkDirs[$j]); #
			$link[$j] = $tmp[$#tmp-1]; # this link has the file tagged on at the end
			                       # so the dir we're looking for is penultimate
			if ($link[$j] eq ".."){ # skip over cases where we go back a directory
				next GotDir;
			}
			#print ("$link[$j] linkdirs\n");
			$LinkOk =0;
		       	for ($k = 0; $k <=$#FDirs; $k++){ # of subdirs matching
				@tmp = split (/\\/, $FDirs[$k]);
				$dir[$k] = $tmp[$#tmp]; # dir we're looking for is end member
				#print ("$dir[$k] dir\n");
				if ($link[$j] eq $dir[$k]){
					$LinkOk = 1;
					next GotDir;
				}
			}
			if (!$LinkOk){ # missing a directory - make it 
				print ("got missing dir: $im_at\\$link[$j] \n");
				$mydir = getcwd;
				$success = mkdir("$im_at\\$link[$j]"); # now empty directory exist
				                     # still need to add default index file to it
				print ("$success success I'm in $mydir\n");
				&MakeDefaultIndex("$im_at\\$link[$j]"); #
				print REP ("Missing Dir for Link at: $im_at\\$link[$j]\n");
								
			}
		}
	}
	if($#FDirs){
	GotLnk: for ($j = 0; $j <= $#dir; $j++) {#check for the existence
			$ExtraDir =0;
		       	for ($k = 0; $k <=$#link; $k++){ # of subdirs matching
				if ($dir[$j] eq $link[$k]){
					$ExtraDir = 1;
					next GotLnk;
				}
			}
			if (!$ExtraDir){ # missing a link for an existing dir
				print REP ("Extra Dir at: $im_at\\$dir[$j]\n");
								
			}
		}
	}
	$ll = $#LinkDirs +12; #set $ll equal to the next index.htm line number after 
	                      #  link lines
	if ($lines[$ll] =~ /9000,9000/){ # this if/else prevents multiple return link lines
		$lines[$ll+1] = "</map>\n";
		$lines[$ll+2] = "</div>\n";
		$lines[$ll+3] = "</body>\n";
		$lines[$ll+4] = "</html>\n";
		$#lines = $ll + 4;
	}
	else {
		$lines[$ll+1] =  "<area shape=\"rect\" alt=\"\" coords=\"0,0,9000,9000\" href=\"..\/index.htm\" title=\"Click to go back\" \/>\n";
		$lines[$ll+2] = "</map>\n";
		$lines[$ll+3] = "</div>\n";
		$lines[$ll+4] = "</body>\n";
		$lines[$ll+5] = "</html>\n";
		$#lines = $ll + 5;
	}

	if (!$image_ok){ #image not match w/ index.htm or index.htm out of kilter
       	         #  report  problem
		 # $lines[0] = "<html>\n";
		 #  The above line is capable of really clobbering things - 
		 #    relax to just specifying an error to REP
		 print REP ("Image not ok in $im_at\n");
	}
}
elsif ($lines[0] =~ /<html>/) { #this is a list subdirectory
	                   # strip off folders and files listed, check
			   # that they are present, and check for ones
			   # not listed that are present - report discrepancies
			   # and write new index.htm
	$k = 0;
	$ll = 0;
	for ($j=0; $j<=$#lines; $j++){  #read what folders and files are in
		                        # are in the list index.htm file
		if($lines[$j] =~/Folder:<\/b>\s*(.*)<\/a>/){
			$LLf[$k] = $1;
			@slFold = split(/\\/, $LLf[$k]);
			$lFolders[$k] = $slFold[$#slFold];
			$k +=1;
		}
		elsif($lines[$j] =~/href="(.*)"/) {
			if($lines[$j] =~/PREVIOUS PAGE/){
			}
			else {
				$lFiles[$ll] = $1;
				$ll +=1;  
			}
		}
	}
	print ("link folders: ");
	for ($j = 0; $j<=$#lFolders; $j++){
		print ("$lFolders[$j]  ");
	}
	print ("\n");
	#now check that the subroutines and files in present dir are
	# matched by lines in index.htm
	# stripping off the path info from the dirs and files present in
	# present directory
	for ($j =0; $j<=$#FDirs; $j++){ # check for directories not found in 
		                        # index.htm
		@jnk = split(/\\/, $FDirs[$j]);
		$Diir[$j] = $jnk[$#jnk];
		#print ("Diir j = $j, $Diir[$j]\n");
		$ExtraDir = 0;
		for ($k=0; $k<=$#lFolders; $k++){
			if ("$Diir[$j]" eq "$lFolders[$k]"){
				$ExtraDir =1;
			}
		}
		if (!$ExtraDir){ #couldn't find link to match dir - report it
			print REP ("Dir added to link index: $FDirs[$j]\n");
			splice (@LLf, $j, 0, "$jnk[$#jnk-1]\\$jnk[$#jnk]"); #puts missing
			                                     #dir link onto LLf
			splice (@lFolders, $j, 0, "$jnk[$#jnk]"); #puts missing
			print ("link folders after splice: ");
			for ($k = 0; $k<=$#lFolders; $k++){
				print ("$lFolders[$k]  ");
			}
			print ("\n");
			print ("LLfs after splice: ");
			for ($k = 0; $k<=$#LLf; $k++){
				print ("$LLf[$k]  ");
			}
			print ("\n");
		}
	}
	for ($j =0; $j<=$#fffs; $j++){  # check for files not found in index.htm
		@jnk = split(/\\/, $fffs[$j]);
		$fname[$j] = $jnk[$#jnk];
			$ExtraFile = 0;
		for ($k=0; $k<=$#lFiles; $k++){
			if ("$fname[$j]" eq "$lFiles[$k]"){
				$ExtraFile =1;
			}
			if ("$fname[$j]" eq "index.htm"){ #gets rid of reporting
				                          # index.htm as an
							  # extra file
				$ExtraFile =1;
			}
		}
		if (!$ExtraFile){ #couldn't find link to match dir - report it
			print REP ("Extra file added to link index: $im_at\\$fname[$j]\n");
			splice (@lFiles, $j,0, "$fname[$j]"); #puts missing
			                                     #file link onto Lfiles

		}
	}
	#next check that links in index.htm exist - remove link lines if files or
	# dirs don't exist
	for ($j =0; $j<=$#lFolders; $j++){ # check for directories not found in 
		                        # index.htm
		$ExtraDir = 0;
		for ($k=0; $k<=$#Diir; $k++){
			if ("$Diir[$k]" eq "$lFolders[$j]"){
				$ExtraDir =1;
			}
		}
		if (!$ExtraDir){ #couldn't find dir to match link - report it
			print REP ("dir missing that was in link index: $im_at\\$lFolders[$j]\n");
			splice (@LLf, $j, 1); #cuts out missing dir link in index.htm
			splice (@lFolders, $j, 1); #cuts out missing dir link in index.htm
		}
	}
	for ($j =0; $j<=$#lFiles; $j++){  # check for files not found in index.htm
			$ExtraFile = 0;
		for ($k=0; $k<=$#fname; $k++){
			if ("$fname[$k]" eq "$lFiles[$j]"){
				$ExtraFile =1;
			}
		}
		if (!$ExtraFile){ #couldn't find file to match link - report it
			print REP ("file missing that was in link index: $im_at\\$lFiles[$j]\n");
			splice (@lFiles, $j, 1); #cuts out missing file link in index.htm
		}
	}
	#final task - write new list index.htm (lines 0-8 should be fine as is
	$lines[0] = "<html>";
	$lines[1] = "$title";
	$lines[2] = "</title>\n</head>\n<body>";
	$lines[3] = "Folders and files in the:";
	$lines[4] = "<br>\n";
	$lines[5] = "<b> $title[$#ttl-2]\\$ttl[$#ttl-1] </b> folder\n";
	$lines[6] = "<br>\n";
	$lines[7] = "<a href=\"../index.htm\"><b>PREVIOUS PAGE</b></a>\n";
	$lines[8] = "<br>\n";
	for ($j = 0; $j<= $#LLf; $j++)  {  #note no more than 100 folder lines in an index.htm
		$lines[9+$j] ="<a href=\"./$lFolders[$j]/index.htm\"> <b>Folder:</b> $LLf[$j]</a><br>\n"
	}
	$cnt = 10 + $#LLf;
	for ( $j =0; $j <= $#lFiles; $j++){
		@splitff = split(/\\/, $fulfils[$j]);
		if ($lFiles[$j] =~ /index\.htm/){
		}
		else {
			$lines[$j+ $cnt] ="<a href=\"$lFiles[$j]\">$lFiles[$j]</a><br>\n" 
		}

	}
	$cnt = 11 + $#LLf + $#lFiles;
	$lines[$cnt] = "<br>\n</body>\n<br>\n</html>\n";
	$#lines =$cnt;
}
elsif ($lines[0] =~/No Content/){ 
# $where = $im_at, $fullfiles[$AlreadyIndex] = $indexf, @fulldirs = @FDirs 
#  @fullfiles = @fffs, \@image = @image);   
	# In this case, 
	#  I. check whether there is stuff besides the index.htm file
	#   A. No - do nothing
	#   B. Yes - 
	#     1. Report extra stuff
	#     2. Make Index (&MakeIndex)
	if ($#FDirs > -1 ){
		print REP ("Extra Dirs added to $im_at:\n");
		for ($j = 0; $j <= $#FDirs; $j++){
			print REP ("$FDirs[$j] ");
		}
		print REP ("\n");
	}
	if ($#fffs > 0 ){
		print REP ("Extra files added to $im_at: ");
		for ($j = 0; $j <= $#fffs; $j++){
			unless ($fffs[$j] =~ /index.htm/){
				print REP ("$fffs[$j] ");
			}
		}
		print REP ("\n");
	}
	if (($#FDirs > -1) || ($#fffs > 0)){
		print ("gotta remake $im_at\\index.htm\n");
		&MakeIndex($at, $ffles, $dir_ref, $image2);
		return (1);
	}	
}
else {
	print REP ("Existing $indexf doesn't fit type - examine\n");
}
print (" $indexf before write_file\n");
write_file ($indexf, @lines);
return (1);
}
#&MakeIndex(\$where, \@fullfiles, \@fulldirs, \@image) ; # make an index from files in directory (list or image,
sub MakeIndex
{
my $here = shift;	# $where passed as a reference
my $wher = $$here; #dereferenced
my $ff = shift;        #full filenames passed reference 
my @ffiles = @$ff; #dereferenced
my $fd = shift;  # full subdir names passed reference
my @ffdirs = @$fd;# dereferenced
my $fi = shift;  # image full filenames passed as reference
my @fimage = @$fi;# dereferenced
if (($#ffiles == -1) && ($#ffdirs == -1)){ # if true, this is an empty dir -
	                                 #  make no-content index.htm
	print ("in MakeIndex no content $wher\n");
	&MakeDefaultIndex($wher);
}
elsif (($#fimage == 0) && ($#ffdirs == -1)){ #if true, this folder has
	                                     # no subfolders and a single
					     # image - make image html
	print ("in MakeIndex single image $wher\n");
	&MakeSingleImageIndex($wher, $fimage[0]);
}
else { # for all other cases, make a list index file
	#print ("in MakeIndex list $wher\n");
	&MakeListIndex($here, $ff, $fd);
}
}
sub MakeDefaultIndex
{
my $directory = @_[0]; #Directory to write index_default.htm to
print ("MakedefaultIndex for $directory\n");
my @noContent;

$noContent[0] = "<!No Content return>\n";
$noContent[1] = "<html>\n";
$noContent[2] = "<head>\n";
$noContent[3] = "<META HTTP-EQUIV=\"Refresh\" CONTENT=\"3; URL=../index.htm\">\n";
$noContent[4] = "<title> No Content </title>\n";
$noContent[5] = "</head>\n";
$noContent[6] = "<body text=#C0C0C0 bgcolor=#00B5EF link=#000080 vlink=#800000 alink=#000080>\n";
$noContent[7] = "<center>\n";
$noContent[8] = "<h1> There is nothing here - going back now </h1><br>\n";
$noContent[9] = "</body>\n";
$noContent[10] = "</html>\n";
print ("$directory before no content write file\n");
write_file ("$directory\\index.htm", @noContent);
}

#	&MakeSingleImageIndex($wher, $fimage[0]);
sub MakeSingleImageIndex
{
	my $weare = shift;
	my $single_image= shift;
	my @lins;
	my @imagepath;
	my @imagename;
	my $image_nosuffix;
	my $imag;
	my $j;
	@imagepath = split (/\\/, $single_image);
	$imag = $imagepath[$#imagepath];
	@imagename = split (/\./,$imag); 
	for ($j = 0; $j<($#imagename); $j++){
		if (!$j){
		$image_nosuffix = "$imagename[0]";
		}
		else {
		$image_nosuffix = join (".", ("$image_nosuffix", "$imagename[$i]"));
		}
	}
	$lins[0] = "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n";
	$lins[1] = "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"DTD/xhtml1-strict.dtd\">\n";
	$lins[2] = "<html xmlns=\"http://www.w3.org/1999/xhtm\" xml:lang=\"e\" lang=\"en\">\n";
	$lins[3] = "<head>\n";
	$lins[4] = "<title>$title</title>\n";
	$lins[5] = "</head>\n";
	$lins[6] = "<body>\n";
	$lins[7] = "<div>\n";
	$lins[8] = "<img src=\"$imag\" alt\"\" usemap=\"#$image_nosuffix\" style=\"border-style:none\" \/>\n";
	$lins[9] = "</div>\n";
	$lins[10] = "<div>\n";
	$lins[11] = "<map id=\"$image_nosuffix\" name=\"$image_nosuffix\">\n";
	$lins[12] =  "<area shape=\"rect\" alt=\"\" coords=\"0,0,9000,9000\" href=\"..\/index.htm\" title=\"Click to go back\" \/>\n";
	$lins[13] = "</map>\n";
	$lins[14] = "</div>\n";
	$lins[15] = "</body>\n";
	$lins[16] = "</html>\n";

	print ("$weare before write_file\n");
	write_file ("$weare\\index.htm", @lins);
}

#	&MakeListIndex($here, $ff, $fd);
sub MakeListIndex
{
	my $j;
	my $count;
	my $whereweat = shift;
	my $wehere = $$whereweat;
        my $fff = shift;
	my @fulfils = @$fff;
	my $fdd = shift;
	my @fuldirr = @$fdd;
	my @splitfd;
	my @splitff;
	my $twodirname;
	my @lindex;
	$lindex[0] = "<html>\n<head>\n<title>";
	my @ttl = split (/\\/, $wehere);
	my $ttle = $ttl[$#ttl-1];
	$lindex[1] = "$ttle";
	$lindex[2] = "</title>\n</head>\n<body>";
	$lindex[3] = "Folders and files in the:";
	$lindex[4] = "<br>\n";
	$lindex[5] = "<b> $ttl[$#ttl-1]\\$ttl[$#ttl] </b> folder\n";
	$lindex[6] = "<br>\n";
	$lindex[7] = "<a href=\"../index.htm\"><b>PREVIOUS PAGE</b></a>\n";
	$lindex[8] = "<br>\n";
	for ( $j =0; $j <= $#fuldirr; $j++){
		@splitfd = split(/\\/, $fuldirr[$j]);
		$twodirname = "$splitfd[$#splitfd-1]\\$splitfd[$#splitfd]";
		unless (($twodirname =~ /Obsolete/) || ($twodirname =~ /Archive/)){

		#print ("splitfd in MakeListIndex: $splitfd[$#splitfd-1]/$splitfd[$#splitfd]\n");
		$lindex[9+$j] ="<a href=\"./$splitfd[$#splitfd]/index.htm\"> <b>Folder:</b> $twodirname</a><br>\n" 
		}
	}
	$count = $#lindex +1;
	for ( $j =0; $j <= $#fulfils; $j++){
		@splitff = split(/\\/, $fulfils[$j]);
		$lindex[$j+ $count] ="<a href=\"$splitff[$#splitff]\">$splitff[$#splitff]</a><br>\n" 

	}
	$count = $#lindex +1;
	$lindex[$count] = "<br>\n</body>\n<br>\n</html>\n";
	
	print ("$wehere 594 before write_file\n");
	write_file ("$wehere\\index.htm", @lindex);
}
sub TimeStamp
{
my $Time;
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
$Time = "$YEAR$MONTH$DAY\_$HOUR$MIN";
return $Time;
}
