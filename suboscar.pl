# usage: suboscar.pl Outline.txt Output.txt
#  perl code that checks outline syntax - note that as of 20150223, Output.txt 
#  is for testing purposes only
#
# 20150122 work outlining structure of suboscar for future refactoring:
#   I. Initiation of variables
#   II. Opening of input/output outlines
#   III. Iterating through the outline, building OutlineArray
#line  382 - need to capture Enumerator info for line

#  Finish at line 301 putting in the rules defined in text lines 126-129

#  Question?  Say a line is in error sequentially.  @Column will be 
#   updated to the new value. The family unit helps organize the errors
#
#REPAIRING:
#  At end, print flag lines in this sequence:
#  Parent
#  (# lines before flagged line)
#  Line before flagged line
#  Flagged line
#  Line afer flagged line
#  (# lines to end of flagged line's family)
#  
#  Suggested repair(s) are shown and user is queried which repair they desire
#     
#LISTS:
#  Metrics to apply to the list structure:
#    1) Number of entries in a directory
#     a) If it exceeds X, columnize
#     b) if it exceeds Y, paginate and suggest adding dir structure
#         by organizing by (choose best one):
#       I) Date
#       II) Geography
#       III) Function
#       IV) Form
#       V) Other natural divisor
#    2) Number of image-page descendents that exist
# Pros win out - lists and images can be interleaved 
#
# Outline Syntax Checker And Repair routine
#
#I.  Notes on acceptable outline syntax:
# A. Lines are of 2 forms (the forms can be interleaved):
#    
#  1. Image : 1 webpage per image 
#   a. satisfies this regular expression:
#    I.  (\s*)(\w*\.{1})\s*(\w*):{1}\s*(\w*\.?\w*),?
#    II. $3:$4 -image map line; ^The colon indicates image page
#     A. On left ($3) is directory name
#      1. No spaces are allowed in the directory name: $d
#      2. Example:  WirelessBridgePowerCable:WirelessBridgePowerCable.png
#       a. $d = WirelessBridgePowerCable
#     B. On right ($4) is image name
#      1. No spaces are allowed in the image name: $image
#       a. $image = WirelessBridgePowerCable.png
#    III. The number of spaces to the left of the enumerator: $1 = $s 
#     A. the $sm = mod4 ($s) is one of 4 types of enumerator
#      1. $sm = 0; @Roman - e.g.  I, LVX 
#      2. $sm = 1; @Cap  -  e.g.  A, C, G, GG
#      3. $sm = 2; @Num  -  e.g.  1,7, 51
#      4. $sm = 3; @Low  -  e.g.  a, c, g, gg
#    IV. is the enumerator including the period $2 = $e
#         example:   b.  WirelessBridgePowerCable:WirelessBridgePowerCable.png
#     A. $e = "b.";
#     B. $n = enumerator sequence number - keeps track of the sibling sequence
#      1. example: VII => $n=6; g => $n=6
#  2. List members in directory structure 
#   a. satisfying the regular expression:
#    I. (\s*)(\w{1}.*)([,;]{1})  are lines listed and downloadable
#      from the parent directory (this was previously either: "Procedures" or
#      "Configurations"
#    II. Note that the lack of a colon (:) in list structure differentiates
#       it from image structure (above)
#   b. Example of list lines (one image line inserted in):
#       (note single-word or -WikiWord file and directory names preferred)
#   **********************************************************************
#    I. StuffThatWorks, 
#     A. Solidworks:StartScreen.jpg
#      1. Documents
#       a. HowToMakeThings.doc,
#       b. NewTricks.txt
#     B. BeingNice.txt
#    II. Stuff that doesn't work
#     A. 7DeadlySins,
#      1. Greed.txt
#      2. Gluttony.txt
#      3. Wrath.txt
#      4. Sloth.txt
#      5. Pride.txt
#      6. Lust.txt
#      7. Envy.txt
#     B. StrainingAtGnats.txt
#     C. Blowoff
#    ***************************
#   c. Downwards compatibility: List members end in:
#    I. "," indicating another list member to follow  
#    II. ";" indicating the last member of a list
#   d. One list member per line preferred, "," & ";" optional
#    I. helps with metrics 
#    II. allows outline checksum
#     A. simple one:
#     B. Adding 1st generation family sizes together
#     C. Counting number of lines in outline
#     D. Two should be equal 
#
#II. Note: repair 
# A. will be very rudimentary - 
#  1. Family oriented
#   a. goal being to make it easy to graft in families
#  2. Queries user about how to fix an out-of-place
#     family 
#  3. able to change single-line errors of
#   a. space 
#   b. simple incrementation problems
#
#III.  OUTLINE RULES: 
# A. note that this area may be customized, eg
#  1. IA1aIA1a  to  IA1a1a1a; 
#  2. IA1a to 1,1.1,1.1.1,1.1.1.1,
#  3. 1.1.1.2,1.2,1.2.1,...; 
#  4. single space to tab, or multiple space)
# B. Rule # 1 - Line # ($i or $array_count) monotonically increases with
#                   each succeeding line.
# C. Rule # 2 - # spaces ($s) before enumerator can go in three directions:
#  1. it can increase by one, indicating spawning of new generation.
#  2. remain the same - indicating birth of another cohort
#  3. and can decrease by any amount as long as $s >= 0
# D. Rule # 3 - Enumerator modulus is $sm = $em = mod4($s)
# E. Rule # 4 - Enumerator sequence number is $n = ($Outline[$i][2]) (found
#               by stepping through the correct $m row of Outline
#               until match gives $n
#  1. if the $s has just incremented (i.e.
#          $Outline[$i][0] = 1+$Outline[$i-1][0] ),
#          $Outline[$i][2] = 0;  in other words, a new group
#          of cohorts has started - cohorts all have the same parent
#  2. if the # spaces remains unchanged from last line:
#          $Outline[$i][0] = $Outline[$i-1][0]), another
#          cohort has been added - increment the enumerator
#          sequence: $Outline[$i][2] = 1 + $Outline[$i-1][2]
#  3. if the # spaces ($s) is less than the line before,
#                       new $n = $Column[$s] + 1;
#  
#IV. Column Array:
# A. @Column keeps track of the family line info (kinfo) while parsing outline
#  - one line at a time,
#  1. It keeps track of sequence number, and line number all the way up the 
#        outline to the top ancestor. 
#  2. Note on how Column works - that when the next line reverts to a smaller 
#      $s, #      all @Column elements larger than $s are set to zero:  
#      i.e. $Column($s+1) = $Column($s=2) ..., $Column($#Column) = 0
# B. Rules for updating @Column[$s] looking at $slast 
#  - used to compare with present line $s
#  1.  $s stays the same: Increment $Column[$s]  ($Column[$s] += 1), all other 
#        $Column[] remain unchanged
#  2.  $s increases by 1: $Column[$s] = 1;  all other values of $Column[] 
#         remain unchanged
#  3.  $s decreases by 1 or more - say by $j: $Column[$s] += 1;  
#          All $Column[$s +1 ... $s + $j] = 0 (and by extension 
#              $Column[$s + $j to 40]  = 0);
#              $Column[$s-$j to 0] remain unchanged;
#
#V. Definition of @Outline array:
# A. $Outline[line number][0] = # spaces to the left before text = $s
# B. $Outline[line number][1] = the literal enumeration (outline number 
#    or letter) - enumeration ends with a "." - $enum has "." stripped off
# C. $Outline[line number][2] = the sequence of the enumerator = $n
# D. $Outline[line number][3] = modulus of the number of spaces = $sm
# E. $Outline[line number][4] = the text after enumeration
# F. $Outline[line number][5] = Original unedited outline line
# G. $Outline[line number][6] = enumerator type modulus = $em 
#  1. Romans = 0, Caps = 1, Nums = 2, Lower =3) 
#  2.  Note: if $Outline[$i][3] != $Outline[$i][6], set flag $Outline[$i][9]
# H. $Outline[line number][7] = # of siblings - only used in the list part
#            presently.  Max $n for any cohort (offspring of the same parent)
# I. $Outline[line number][8] = Family size - # of descendants, 
#  1. $f = The number of lines before the next sibling or elder or end of file. 
#    a. this requires reading and processing the entire 
#         outline once before finishing for every line
#    b. once the table is constructed, the algorithm for filling in family size 
#         is shown in the OUTER3 block of code below
# J. $Outline[line number][9] = (flag) = 0 no mistake 
#  1. |(bitwise or) 1 - mismatch of modulus
#  2. | 2  - column spacing rule broken (2 or more increase in $s) 
#  3. | 4 - outline enumerator is not a member of the enumerator sets
#  4. | 8  - sequence number doesn't match - new line has same spaces as previous
#  5. | 16 - sequence number doesn't match - new line has less spaces than previous
#  6. | 32 - sequence number doesn't match - new line has one more space than previous
#  7. | 64 - sequence number doesn't match - new line has greater than one more space
# K. $Outline[line number][10] = (flag)  = 
#  1.  0 = image page line
#  2.  1 = list line
#           
#
#VI. oscar program process: 
# A. read in the outline to be checked and create the following array:
#  1. @Outline, an organized mapping of the information in the outline.txt
#  2. @Column, keeps track of the current enumerator sequence numbers ($n) 
#      for each value of $s (number of spaces).  The array updates with 
#      each new line of outline.txt
#
#VII. OutlineAxioms 
# A. Causality - nothing following the present line can make it right or wrong
# B. A family is the basic unit and is fractal and recursive.  A family is defined
#       as a line and all dependent lines below it (all the sequence of lines that 
#       have more spaces before the enumerator than the given line.  
#  1. An example:  
#   a. royalty
#    I. kings
#    II. queens
#    III. princes
#    IV. princesses
#    V. dukes
#    VI. viscounts
#   b. politicians
#  2.The family of royalty includes itself and the next 6 lines.  
#   a. "b. politicians" starts another family.
#   b. Note that C. royalty and D. politicians belong to a more inclusive family - Leaders: 
#         I. Leaders
#          A. Officers
#          B. Organizers
#          C. royalty
#          D. politicians
#   c. Royalty and politicians both belong to the I. Leaders family
#   d.   The progeny and parent can be thought of as a unit, a universe unto itself.
#          
#VIII.  PL: List of processes this program does:
#     I. Reads an outline and checks it for correct syntax
#      A. Read first line
#      B. Parse the line into:
#       1. number of spaces before the enumeration: $Outline[$i][0]
#       2. the enumeration, Outline[$i][1] (and $enum with "." chopped off) 
#	3. the whole line - useful for undo's: $Outline[$i][5]
#       4. the argument after the emumeration
#       5. update the appropriate member of @Column with latest enumeration index
#       6. increment family size for all 
#      C. Check that the line being checked has an enum and space count that 
#         follows the rules: 
#       1. Is there parity?  Number of spaces and enumerator type match?
#        a. determine modulus of pre-enumeration spaces $sm = mod4($s)
#        b. find $em and #n by matching $enum to a member of @Enums array 
#       2. Is there incremental continuity?  Enumerator of the correct sequence?
#       3. If checks ok, go to B.  Read next line
#       4. If doesn't check ok, go to II.
#     II. Flags every error line and reports error type
#     III. Prints error patches one at a time and allows user to choose fix
#     IV. Updates the Array representation of the outline
#     V. Iterates I-IV until there are no errors
#     VI. Writes outline file to $foloc 
#
my @Outline; 
#    Array that keeps track of information about the individual lines in the outline
my $maxColumn = 40;
my @Column = (0) x $maxColumn; 
#    Array that keeps track of the latest enumeration sequence for each column - e.g.:
#    Here's a sample outline 
#    I. Rivers               line 1
#     A. Nile                line 2
#     B. Mississippi         line 3
#      1. Red                line 4
#      2. Arkansas           line 5
#      3. Missouri           line 6
#    II. Oceans              line 7
#
#     going through Outline line by line, $Column reported
#     line 1 - $Column[0] = 1, $Column[1..7] = 0
#     line 2 - $Column[0] = 1, $Column[1] = 1, $Column[2..7] = 0
#     line 3 - $Column[0] = 1, $Column[1] = 2, $Column[2..7] = 0
#     line 4 - $Column[0] = 1, $Column[1] = 2, $Column[2] = 1, $Column[3..7] = 0
#     line 5 - $Column[0] = 1, $Column[1] = 2, $Column[2] = 2, $Column[3..7] = 0
#     line 6 - $Column[0] = 1, $Column[1] = 2, $Column[2] = 3, $Column[3..7] = 0
#     line 7 - $Column[0] = 2, $Column[1] = 0, $Column[2] = 0, $Column[3..7] = 0
#       note that fininshing the Rivers family zeros all $Column[$i] for $i>0
#
#  Each Column element is the enumeration sequence number, $n for the active
#    family rank (column)
#  Once the present line is parsed the code uses $outline[$i][0] to determine 
#   which $Column[$outline[0]] needs updating and checking to ensure that the  
#    1) the enumeration is of the right type (e.g. Roman Numerals, ... ) and 
#    2) enumeration value increments sequentially, if not, an error flag is raised 
#
# Note to self:  I need a way of determining the index position of a given $enum 
#   (for example "G" has index 6, "A" has index 0
#    Here's a way from Big Vic April 26, 2001 [perlmonks.org/?node_id=75660]:
#        my @a = ( 1 .. 1_000_000 ); # some large array
#        my $want = 5843;
#        my $i = 0;
#        ++$i until $a[$i] == $want or $i > $#a;
#    
my @Enums; # Array of arrays of enumerators of the 4 types listed below:
my $enum; # enumerator place holder
my $sm; # enumerator modulus calculated from space count
my $em; # enumerator modulus determined from set membership
my $i = 0; #counter
my $j = 0; #counter
my $k = 0; #counter
my $l = 0; #counter
my @Romans; # Array that has the sequence of Roman numerals in it
my @Caps; # Array that has the sequence of Capital letters in it
my @Lower; # Array that has the sequence of lower-case letters in it
my @Nums; # Array that has the sequence of numbers in it
my $oloc = 'OutlineBroke.txt'; #note that these are normally taken from
                               # the command argument list, but are 
			       # coded in for using komodo debugger
my $foloc = 'Outi.txt';        # same as above
my $line; # this keeps the current outline line string
my $s; # number of spaces before enumeration
my $slast; # number of spaces before enumeration for the previous line
my $n; # enumeration sequence (e.g. for "a", $n=1; "b", $n=2; "IV", $n=4)
my $array_count;    #This keeps track of what line in the outline we're on
my $eoflag = 0;    #This flag is set to 1 when the last line is reached
@Romans = ('I','II','III','IV','V','VI','VII','VIII','IX','X','XI','XII', 
	'XIII','XIV','XV','XVI','XVII','XVIII','XIX','XX','XXI','XXII',
	'XXIII','XXIV','XXV','XXVI','XXVII', 'XXVIII','XXIX','XXX','XXXI',
	'XXXII','XXXIII','XXXIV','XXXV','XXXVI','XXXVII','XXXVIII',
	'XXXIX','XL','XLI','XLII','XLIII','XLIV','XLV','XLVI','XLVII',
	'XLVIII','XLIX','L','LI','LII','LIII','LIV','LV','LVI','LVII',
	'LVIII','LIX','LX','LXI','LXII','LXIII','LXIV','LXV','LXVI',
	'LXVII','LXVIII','LXIX');
my $maxRomans = $#Romans;
print ("$maxRomans - the number of Roman numerals: $Romans[68] \n");
@Nums = (1 .. 128);
my $maxNums = $#Nums;
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
$Enums[0] = [@Romans];
$Enums[1] = [@Caps];
$Enums[2] = [@Nums];
$Enums[3] = [@Lower];
$array_count = 0;  #this increments with each succeeding line of the outline
open (OUTL, "<$oloc") || die "OUTL FILE NOT FOUND.\n" ;
open (FIXOUT, ">$foloc") || die "Fixed outline file not opened.\n";
print FIXOUT (" 126=$Enums[2][125],  g=$Enums[3][6],  C=$Enums[1][2], VII=$Enums[0][6]\n");
foreach $line (<OUTL>) {   #I.A. (see line #204 above for Process List outline)
	$Outline[$array_count][5] = $line;
	$Outline[$array_count][7] = 0; #unused so far
	$Outline[$array_count][8] = 0; #start out zeroed out
	$Outline[$array_count][9] = 0; #start out zeroed out
	print ("line $array_count: $line\n");
        # regular expression matching and filling in the table:
	if ($line =~/(\s*)(\w*\.{1})\s*(\S*)\s*:{1}\s*(\S*)[;,]?/) {
	          	# This is an image map line - not a list line
		$Outline[$array_count][10] = 0;
		$Outline[$array_count][0] = length( $1 ); #I.B.1 - number of spaces before enumerator
		$s = $Outline[$array_count][0]; # This counts number of left spaces
	        $Outline[$array_count][3] = $s % 4;  #space count modulus: $sm
	        $sm = $Outline[$array_count][3];	
		$enum = $2;
		$Outline[$array_count][1] = $enum;  #I.B.2 - the enumerator
		chop $enum; # deletes the period in the $enum variable
		$Outline[$array_count][5] = $line; #I.B.3 - the whole line, including spaces
		$Outline[$array_count][4] = "$2$3:$4"; #I.B.4 - the argument after enumeration
		# from this line, and for about 20 lines we are determining the @Column array
		if ($array_count == 0) {
			$slast = -1;
			$Column[0] = 1; #Initialize
		}
		else {
			$slast = $Outline[$array_count-1][0];
		}
		if ($slast == $s){ # this line and previous lines are siblings	
        		$Column[$s] += 1;
			#print ("A line $array_count slast = s\n");

			unless ($array_count ==0){ #previous line sibling had no family other than self
		        	$Outline[$array_count-1][8] = 1; # family size of previous line is 1
				#print ("O[8] should be 1: $Outline[$array_count-1][8], line: $array_count\n");
			}
		}
		elsif ($s == ($slast + 1)){ #present line is a child of previous line
			$Column[$s] = 1;
		}
		elsif ($s < $slast){ #if true, then we have reached the end of at least one cohort line (family)
			             # and must zero out higher order sequence counters in @Column
				     #print ("C array_count = $array_count, s = $s, slast = $slast\n");	
			$Column[$s] +=1;
			for ($k = $s+1; $k<($maxColumn + 1); $k++){
				$Column[$k] = 0;
			}
			#In the following lines, we determine family size for whichever preceeding lines
			#  families are ended with this line - e.g. the following outline lines followed
			#    with the family count ends with the line: II. Tutors:
			#       OUTLINE		    family size
			#---------------------------------------
			#       I. Lab Assistants	7 
			#        A. Types 		6
			#         1. Mammals		5
			#          a. Rats		4
			#           I. Wild		3
			#            A. Norwegian	2
			#             1. Male		1
			#       II. Tutors		count depends on following lines
			#
			# First, it is always the case that the previous line consists of a family of 1
			$Outline[$array_count-1][8] = 1;
			#print ("outline[arraycount-1][8] = $Outline[$array_count-1][8]\n");
		        # Next, work backwards determining the family count for other terminated families
	OUTER2:		for ($k = $array_count-2; $k >= 0; $k--){
		#	print ("k = $k, array_count = $array_count\n");
				if($Outline[$k][8] > 0) { # if true, this family line has already terminated
					#print ("outline[$k][8] = $Outline[$k][8]\n");
					next OUTER2;
				}	
				else{
					$Outline[$k][8] = $array_count - $k;
					#			print ("YES - we set [8] for $k\n");
				}
				last if($Outline[$k][0] <= $Outline[$array_count][0]);  # we don't need to check any higher up
			}
		}
		else { # error in outline - column spacing rule broken (2 or more increase in $s)
			$Outline[$array_count][9] = $Outline[$array_count][9] | 2;
		}
                          # go through expected enumeration class until match to determine 
#                             sequence number - 
		$i = 0;
		++$i until $Enums[$sm][$i] eq $enum or $i > $#{$Enums[$sm]};  # find matching enumerator to determine $n
		 # if enumerator isn't of the expected mode ...
		 #print FIXOUT ("$Enums[$sm][$i] = $enum, $sm = sm, $i = i\n");
		 #print FIXOUT ("$#{$Enums[$sm]} = max cnt; $sm = sm, $i = i\n");
		if ($i > $#{$Enums[$sm]}) { # flag this line - $sm doesn't match $em
			$Outline[$array_count][9] = $Outline[$array_count][9] | 1; # bit 1 - mismatch of modulus
			#next we have to determine modulus and sequence #
			# of actual $enum and $n
OUTER:			for ($j = 0; $j<4; $j++){
				next OUTER if ($j == $sm); #we've already looked through the $sm set
				$k = 0;
	       	        	 ++$k until $Enums[$j][$k] eq $enum  # go through expected enumeration 
#                                       class until match to determine sequence number
					or[$k] > $#{$Enums[$j]};  # if not found, jump out
	       	        	if ($k > $#{$Enums[$j]}) { # no match for $em. Either do next modulus type
#                                               search or report no match
					if($j == 4) { # We've checked through the entire set and found no 
						#        enumeration match -
						#        set the logical-OR 4's bit in $Outline[$array_count][9]
						$Outline[$array_count][9] = 4 | $Outline[$array_count][9];
					next OUTER;
					}
				}
				else {  # This branch taken when the mismatched enumerator is found 
					$n = $k + 1; # sequence number of enumerator
		       			$Outline[$array_count][2] = $n;	#I.C.1.b - the following if statement checks that its order
					#                                  number matches outline syntax (sequentially increasing cohorts)
					$Outline[$array_count][6] = $sm; # modulus of enumerator type matches spaces modulus for good outlines 
					if ( $slast == $s ) { # sequence number ($n) should be equal to $Column[$s];                       
						if ($Column[$s] != $n) { #otherwise set sequence error flag and repair $Column[$s]
							$Outline[$array_count][9] = $Outline[$array_count][9] | 8;  
							#print FIXOUT ("Debug $Outline[$array_count][5], $array_count - Error 8\n");
						        $Column[$s] = $n; # set $Column[$s] to $n and also zero out any higher sequence members
					                     # of @Column
			     			  	for ($k = $s+1, $k<($maxColumn + 1), $k++){
							 	$Column[$k] = 0;
							}
						}
					}
					if ( $slast > $s ) { # sequence number ($n) should be equal to $Column[$s], but                       
						if ($Column[$s] != $n) { #otherwise set sequence error flag and repair $Column[$s]
							$Outline[$array_count][9] = $Outline[$array_count][9] | 16;  
							#print FIXOUT ("Debug $Outline[$array_count][5], $array_count - Error 16\n");
						        $Column[$s] = $n; # set $Column[$s] to $n and also zero out any higher sequence members
					                     # of @Column
			     			  	for ($k = $s+1, $k<($maxColumn + 1), $k++){
							 	$Column[$k] = 0;
							}
						}
					}
					if ( ($slast +1) == $s ) { # sequence number ($n) should be equal to $Column[$s], but                   
						if ($Column[$s] != $n) { #otherwise set sequence error flag and repair $Column[$s]
							$Outline[$array_count][9] = $Outline[$array_count][9] | 32;  
							#print FIXOUT ("Debug $Outline[$array_count][5], $array_count - Error 32\n");
					        	$Column[$s] = $n; # set $Column[$s] to $n and also zero out any higher sequence members
					                     # of @Column
			     		  		for ($k = $s+1, $k<($maxColumn + 1), $k++){
						 		$Column[$k] = 0;
							}
						}
					}
					if ( ($slast +1) < $s ) { # sequence number ($n) should be equal to $Column[$s], but                     
						if ($Column[$s] != $n) { #otherwise set sequence error flag and repair $Column[$s]
							$Outline[$array_count][9] = $Outline[$array_count][9] | 64;  
					        	$Column[$s] = $n; # set $Column[$s] to $n and also zero out any higher sequence members
					                     # of @Column
			     		  		for ($k = $s+1, $k<($maxColumn + 1), $k++){
						 		$Column[$k] = 0;
							}
						}
					}
				}
			}
		}
		else {  # This branch taken when the enumerator belongs to the set that matches the space modulus
			$n = $i + 1; # sequence number of enumerator
			#	print FIXOUT ("sequence number =$i,$n enum = $enum\n");
		        $Outline[$array_count][2] = $n;	#I.C.1.b - the following if statement checks that its order
			#                                  number matches outline syntax (sequentially increasing cohorts)
			$Outline[$array_count][6] = $sm; # modulus of enumerator type matches spaces modulus for good outlines 
			if ( $slast == $s ) { # sequence number ($n) should be equal to $Column[$s];                       
				if ($Column[$s] != $n ) { #otherwise set sequence error flag and repair $Column[$s]
					$Outline[$array_count][9] = $Outline[$array_count][9] | 8;  
					#		print FIXOUT ("Debug2 $Outline[$array_count][5], $array_count - Error 8\n");
					print FIXOUT ("s = $s, column[s]=$Column[$s], n = $n; $enum, $array_count, Error 8\n");
				        $Column[$s] = $n; # set $Column[$s] to $n and also zero out any higher sequence members
					                     # of @Column
			     	  	for ($k = $s+1, $k<($maxColumn + 1), $k++){
					 	$Column[$k] = 0;
					}
				}
			}
			if ( $slast > $s ) {# This line shows the end to some number of families
			       	# sequence number ($n) should be equal to $Column[$s]                       
				if ($Column[$s] != $n) { #otherwise set sequence error flag and repair $Column[$s]
					$Outline[$array_count][9] = $Outline[$array_count][9] | 16;  
					#print FIXOUT ("Debug2 $Outline[$array_count][5], $array_count - Error 16\n");
					#print FIXOUT ("s = $s, column[s]=$Column[$s], n = $n Error 16\n");
				        $Column[$s] = $n; # set $Column[$s] to $n and also zero out any higher sequence members
					                     # of @Column
			     	  	for ($k = $s+1, $k<($maxColumn + 1), $k++){
					 	$Column[$k] = 0;
					}
				}
			}
			if ( ($slast +1) == $s ) { # sequence number ($n) should be equal to $Column[$s], but                       
				if ($Column[$s] != $n && $n != 0) { #otherwise set sequence error flag and repair $Column[$s]
					$Outline[$array_count][9] = $Outline[$array_count][9] | 32;  
					#print FIXOUT ("Debug2 $Outline[$array_count][5], $array_count - Error 32\n");
					print FIXOUT ("s = $s, column[s]=$Column[$s], n = $n; $enum, $array_count;Error 32\n");
				        $Column[$s] = $n; # set $Column[$s] to $n and also zero out any higher sequence members
					                     # of @Column
			     	  	for ($k = $s+1, $k<($maxColumn + 1), $k++){
					 	$Column[$k] = 0;
					}
				}
			}
			if ( ($slast +1) < $s ) { # sequence number ($n) should be equal to $Column[$s], but                       
				if ($Column[$s] != $n) { #otherwise set sequence error flag and repair $Column[$s]
					$Outline[$array_count][9] = $Outline[$array_count][9] | 64;  
				        $Column[$s] = $n; # set $Column[$s] to $n and also zero out any higher sequence members
					                     # of @Column
			     	  	for ($k = $s+1, $k<($maxColumn + 1), $k++){
					 	$Column[$k] = 0;
					}
				}
			}
		}
	}
	#print ("i = $i\n"); #Test print                   
	elsif ($line =~/(\s*)(\w*\.)\s*(\w*)\s*(\.{3})\s*(.*)/) { 
              # this reg expression is of the form: 
# IV. Procedures ... file1.jpg, file2.jpg, file3.jpg,
		print ("This is a list line, $array_count\n");
		$Outline[$array_count][10] = 1; #
		if($line =~/(\s*)(\w*\.)\s*\.\.\.\s*(.*)/)  { #starting list line
		}
	}
	else  {
		print ("This aint nothing: $array_count\n");
	}
$array_count++;
}
# Now that we've gotten to the last line, we still have to finish filling in values:
#       $Outline[$all][8] (for those values still set to 0 including the last
$Outline[$array_count - 1][8] = 1; # fill in family size for last line in outline
OUTER3:	for ($k = $array_count-2; $k >= 0; $k--){
		print ("k = $k, array_count = $array_count\n");
		if($Outline[$k][8] > 0) { # if true, this family line has already terminated
			#print ("outline[$k][8] = $Outline[$k][8]\n");
			next OUTER3;
		}	
		else{
			$Outline[$k][8] = $array_count - $k;
			print ("YES - we set [8] for arraycount: $array_count, $k\n");
		}
		last if($Outline[$k][0] == 0);  # we don't need to check any higher up
	}
#
for ($i = 0; $i<$array_count; $i++){
print FIXOUT ("$Outline[$i][0], $Outline[$i][1], $Outline[$i][2], $Outline[$i][3], $Outline[$i][6], $Outline[$i][8], $Outline[$i][9], $Outline[$i][10]\n");
}
#

	
#REGEXP to check for Roman numerals: ^[MDCLXVI]+$
#  stricter:  ^(?=[MDCLXVI])M*(C[MD] | D?C*)(X[CL]|L?X*)(I[XV]|V?I*)$
#                  Fixing algorithm: If by solely varying the SPE (spaces per 
#                   enumeration), this line can be fixed, 
#                   tenatively fix it and update @Outline for that line.  
#                   If this line can be fixed solely by going
#                   to a higher or lower array value for the enumeration in the 
#                   same class as it is in presently (either in Romans, Caps, 
#                   Lower, or Numeral), tenatively go for it :)
#
#               Here's a list of exceptions/additions/changes to the outline:
#               1) typo - placing the wrong sequential sibling
#               2) spaceo - indenting the wrong number of spaces so there is a 
#                   class/zero count conflict
#               3) add another sibling (plus descendents)
#               4) take away a sibling
#
#
#               Here's a list of ok segues (where X denotes a space:
#                                            XF
#                                            XG
#                                            XX1
#                                            XX2
#                                            II  (note that II has to be the 
#                                                 next in the zero column series)
#           With reference to the previous line:
#           OK         1) Start line - 0 spaces, first array entry of Romans
#           Allow:     2) Same number of spaces before enum, incremental array 
#                          value (eg "F" then "G":
#                                   XF -> XG
#                      3) One more space before enum, enum starts with 1st array 
#                          value in child class
#                      4) One or less spaces before enum, enum starts with the 
#                          next sequential array value in @Column, where the 
#                          $i is the number of spaces before enum
