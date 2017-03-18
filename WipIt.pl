#!/usr/bin/perl
#usage perl WipIt $InDir $Wdir
# This routine is similar to makeout.pl in that it is recursively called and 
#  uses readdir to go through $IDr and capture the following into an array: @I
#   $I[$i][0] full pathname (relative to root $IDr) of entry
#   $I[$i][1] 1 if directory, 0 if file
#
#   Once that is built, it is time to go through $WDr and look for matches using
#    File::Find.  If we find a directory match and subdirectories in $IDr are 
#    not present in $WDr, we'd like to copy them over 
my $IDr = "InDir1";
my $WriteDir = "WDir1";
use File::Find;
use File::Path;
use File::Copy; # has copy and move commands
use File::Copy::Recursive qw(fcopy rcopy dircopy fmove rmove dirmove);
use File::Compare;
use Cwd;
my $mydir;
my $depth = 0; #First time through, recursion depth is 0 (means we're in the
            # InDir root folder
my (@Matchd, @Matchf);
my $LookFor;
my @FFSplit;
&WipIt($IDr, $depth);

sub WipIt {
	my ($path, $d)  = @_; # $path is InDir from direct.pl call
	               # $d is recursion depth
	my ($j, $k, $l);
	my @files;
	my $Pass;
	#print ("LookFor = $LookFor\n");
	#print ("Wdir  = $WriteDir\n");
	my $NoArchive = 0; # hardwired for debugging purposes - will be parsed 
	                   #  in direct.pl
	opendir (DIR, $path)
		or die "Unable to open $path: $!";
	@files = grep { !/^(\.){1,2}|~$|.*db$|^\[/ } readdir (DIR);#my try	
	closedir (DIR); # This call fills in files from whatever subdir we
	                #  are presently in inside InDir
	#print ("files  = @files\n");
	my @fullfiles = map { $path . '\\' . $_ } @files;  #full path name
	#print ("fullfiles read in = @fullfiles\n");
	for ($j = 0; $j <= $#files; $j++) {
		#print ("j = $j Total #j = $#files\n");
		if (-d "$fullfiles[$j]") {
			#print ("fullfiles dir = $fullfiles[$j]\n");
			# Root directories are never written to $WD1 because
			#  there is no parent to show where they go.  Root
			#  directories are only containers of transferrable
			#  similar to a wharf at a dock as opposed to a barge.
			# There are a InDir1 and WDir1 in 
			# DocManager/Sandbox as a test case to see
			# First: find like directories in WDir
			# print ("yep $fullfiles[$j] is a directory\n");
			if ($d) { # no matching necessary for root folders
				  # for InDir
				  #print ("fullfiles before split = $fullfiles[$j]\n");
				@FFSplit = split(/\\/, $fullfiles[$j]);
				#print ("FFSplit = $FFSplit[0] $FFSplit[1] $FFSplit[2]\n");
				find (\&Wanted, $WriteDir); # This fills in an 
				         # array with matching subdirs found in
					 # $WriteDir
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
			&WipIt($LookFor, $d); # recurse   
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
			#print ("Matchf =$Matchf[$k], k = $k\n");
			#print ("fullfiles = $fullfiles[$j], j = $j\n");
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
					#print ("Matchf =$Matchf[$k], k = $k\n");
					#Create archive folder
					$Pass = $Matchf[$k];
					#print ("pass = $Pass\n");
					$Ark = CreateArchive( $Matchf[$k] ); # need to split out
					#print ("archive pathname is: $Ark\n");
					  # Wdirfullname pathnames and add 
					  #  archive to parent directory of file.
					unless (mkdir $Ark) {
						die "$Ark not made $!";
					}
					$mydir = getcwd;
					#print ("my present dir: $mydir\n");
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
	if(/$FFSplit[$#FFSplit -1]/){
		push (@Matchd, $File::Find::name); # save full WriteDir pathname
		                                   # that matches InDir parent
						   # folder of InDir folder 
						   # being operated on
	}
}
sub Wanted3
{
	#print ("looking for $_ LookFor= $LookFor\n");
	#match the parent directory of the InFile directory with $_
	if(/$LookFor/){
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
	# Takes subroutine argument (full pathname of to be saved file in
	#   WDir, splits it, and creates an archive directory in the WDir 
	#   folder the saved file is in.
	my $pname = $_[0];
	#print ("pname as passed = $pname\n");
	my @gname = split(/\//, $pname);
	#print ("pname after split = @gname\n");
	my $Arc;
	my $time = TimeStamp();
	my $ArcTime = "Archive$time";
	$#gname -=1; # remove last element from pathname (file itself)
	$Arc =join ("/", (@gname, $ArcTime)); 
	#print ("Arc pathname is $Arc\n");
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
