#!/usr/bin/perl -w
# Sutfak : Quick GUI Lojban dictionary
# Written by David "Carbon" Simon
# Licensed under the Artistic License
#
# Version 0.6
#
# TODO (in order of importance):
# - Compound cmavo
# - Font selection
# - Fu'ivla
# - Wordlist display mode
# - Notepad area
# - Ability to clear the log

use Tk;
use strict;
use FindBin;

### Chdir to the script's location, so we can get the dictionary files
chdir $FindBin::Bin;

### Declarations of the hashes

#Gi'uste format:
#Key - Word
#Value - [ Rafsis (comma-space seperated), Gloss word, Definition ]
my %gihuste;

#Ma'oste format:
#Key - Word
#Value - [ Selma'o, Gloss word, Definition, Rafsis (comma-space seperated) ]
my %mahoste;

#Selma'oste format:
#Key - Selma'o (not lowercased)
#Value - [ Words ]
my %selmahoste;

#Rafste format:
#Key - Rafsi
#Value - Word
my %rafste;

#Gloss_words format:
#Key - Gloss word
#Value - [ Words ]
my %gloss_words;

### Parsing stuff into the hashes

#Parse the gismu definitions list into the gihuste and gloss_words hashes
open GISMUS, "gismu.dat" or die("Couldn't open gismu.dat");
for (<GISMUS>) {
	chomp;
	my ($word, $rafsis, $gloss, $def) = split(/\t/);
	$rafsis =~ s/ /, /g;
	$gihuste{$word} = [ $rafsis, $gloss, $def ];
	push @{$gloss_words{lc($gloss)}}, $word;
	$rafste{substr($word, 0, 4)} = $word; #The standard 4-letter mid-lujvo rafsi every gismu has
}
close GISMUS;

#Parse the cmavo definitions list into the mahoste, selmahoste, and gloss_words hashes
open CMAVOS, "cmavo.dat" or die("Couldn't open cmavo.dat");
for (<CMAVOS>) {
	chomp;
	my ($word, $selmaho, $gloss, $def) = split(/\t/);
	$mahoste{$word} = [ $selmaho, $gloss, $def ];
	push @{$selmahoste{$selmaho}}, $word;
	
	#If this cmavo is in a numbered selma'o, insert another entry for the selma'o minus the number
	if ($selmaho =~ /^(.+)\d+$/) {
		push @{$selmahoste{$1}}, $word;
	}
	
	push @{$gloss_words{lc($gloss)}}, $word;
}
close CMAVOS;

#Parse the rafsi list into the rafste hash
open RAFSIS, "rafsi.dat" or die("Couldn't open rafsi.dat");
for (<RAFSIS>) {
	chomp;
	my ($rafsi, $word) = split(/ +/);
	$rafste{lc($rafsi)} = $word;

	#If it's a cmavo, then add it to the cmavo's entry
	if (length($word) != 5) {
		if (exists $mahoste{$word}[3]) {
			$mahoste{$word}[3] .= ", " . $rafsi;
		} else {
			$mahoste{$word}[3] = $rafsi;
		}
	}
}
close RAFSIS;

### Attempts to decompose a lujvo into its component words
### Returns an array of expanded words, or empty array if not valid lujvo
### Arguments: The lujvo, the current index, remaining args are the words decoded so far.
sub lujvo_dec {
	my $lujvo = shift @_;
	my $idx = shift @_;
	my @words = @_;
	
	$lujvo =~ s/y//; #Remove any buffering y's
	
	if (length($lujvo) < 6 || length($lujvo) - $idx < 3) {
		#If the lujvo isnt long enough to have more than one rafsi, its invalid
		#Or, if we dont have enough characters left for a rafsi, then the lujvo isn't valid
		splice @words;
		return @words;
	}
	
	if (length($lujvo) - $idx == 5 && exists $gihuste{substr($lujvo, $idx, 5)}) {
		#Embedded full gismu at end of word
		push @words, substr($lujvo, $idx, 5);
		return @words;
	}
	
	if (length($lujvo) - $idx >= 4 && exists $rafste{substr($lujvo, $idx, 4)}) {
		#4 letter rafsi
		my @deeperwords = @words;
		push @deeperwords, $rafste{substr($lujvo, $idx, 4)}; 
		if ($idx+4 != length($lujvo)) {
			my @deeperwords = lujvo_dec($lujvo, $idx+4, @deeperwords);
			if (@deeperwords) {
				return @deeperwords;
			}
		} else {
			return @deeperwords;
		}
	}
	
	if (length($lujvo) - $idx >= 3 && exists $rafste{substr($lujvo, $idx, 3)}) {
		#3 letter rafsi
		my @deeperwords = @words;
		push @deeperwords, $rafste{substr($lujvo, $idx, 3)};
		if ($idx+3 != length($lujvo)) {
			my @deeperwords = lujvo_dec($lujvo, $idx+3, @deeperwords);
			if (@deeperwords) {
				return @deeperwords;
			}
		} else {
			return @deeperwords;
		}
	}
	
	if (substr($lujvo, $idx, 1) eq "r" || substr($lujvo, $idx, 1) eq "n") {
		#Hyphen r or hyphen n
		return lujvo_dec($lujvo, $idx+1, @words);
	} 		
	
	#If we haven't got any of the above, the lujvo isn't valid
	splice @words;
	return @words;
}

### Takes the gismu to check for, returns string of info or an empty string if no match
sub gismu_lookup {
	my $result = "";
	my ($in) = @_;
	if (exists $gihuste{$in}) {
		$result .= "Gismu {" . $in . "}";
		$result .= ", with rafsi {" . $gihuste{$in}[0] . "}" if ($gihuste{$in}[0] ne "");
		$result .= ", glossing to {" . $gihuste{$in}[1] . "}:\n"; 
		$result .= $gihuste{$in}[2];
	}
	return $result;
}

### Takes the cmavo to check for, returns string of info or an empty string if no match
sub cmavo_lookup {
	my $result = "";
	my ($in) = @_;
	if (exists $mahoste{$in}) {
		$result .= "\n" if ($result ne "");
		$result .= "Cmavo {" . $in . "}, of selma'o {" . $mahoste{$in}[0] . "}";
		$result .= ", with rafsi {" . $mahoste{$in}[3] . "}" if (exists $mahoste{$in}[3]);
		$result .= ", glossing to {" . $mahoste{$in}[1] . "}:\n"; 
		$result .= $mahoste{$in}[2];
	}
	return $result;
}

sub selmaho_lookup {
}

### Takes the gloss word to check for, returns string of info or empty string if no match
sub gloss_lookup {
	my ($in) = @_;
	my @matches;
	if (exists $gloss_words{$in}) {
		foreach my $word (@{$gloss_words{$in}}) {
			if (length($word) == 5) {
				push @matches, gismu_lookup($word);
			} else {
				push @matches, cmavo_lookup($word);
			}
		}
	}
	
	return "Gloss word {" . $in . "}, similar to Lojban word(s):\n" . join("\n", @matches);
}

### Takes the rafsi to check for, returns string of info or empty string if no match
sub rafsi_lookup {
	my ($in) = @_;
	if (exists $rafste{$in}) {
		my $result = "Rafsi {" . $in . "}, for {" . $rafste{$in} . "}:\n";
		if (length($rafste{$in}) == 5) {
			return $result . gismu_lookup($rafste{$in});
		} else {
			return $result . cmavo_lookup($rafste{$in});
		}
	}

	return "";
}

### Create the GUI

#The window
my $mw = MainWindow->new;
$mw->title('Sutfak');

#The output display text area, with some statistics displayed at start
#We use a Text instead of a Label, because Labels dont seem to scroll
my $output_log = $mw->Scrolled('Text', -wrap => 'word',  -scrollbars => 'e');
$output_log->insert('end', scalar(keys(%mahoste)) . " cmavos.\n");
$output_log->insert('end', scalar(keys(%gihuste)) . " gismus.\n");
$output_log->insert('end', scalar(keys(%gloss_words)) . " gloss words.");
$output_log->configure(-state => 'disabled');

# The frame containing the entry field and buttons
my $frame = $mw->Frame();

#The word entry field
my $entry = $frame->Entry();
$entry->focus();

### Sets up the output log for insertion
sub output_begin {
	#Temporarily allow changes to the output log
	$output_log->configure(-state => 'normal');
	$output_log->insert('end', "\n"); 
	
	#Scroll to where the top of the output will be
	$output_log->yview("moveto", 1);
}

### Locks the output log
sub output_end {
	#Prevent the user from editing the output log
	$output_log->configure(-state => 'disabled');
}

#The Word button and associated subroutine
my $word_button = $frame->Button(-text => 'Word', -command => sub {
	output_begin();
	
	#Clean up the input string
	my $in = lc($entry->get());
	$in =~ /^\s*(.+)\s*$/ or $in = "";
	if ($in ne "") { 
		$in = $1;
	} else {
		$output_log->insert('end', "\n   No input given.");
		$output_log->yview("moveto", 1); #Scroll down to the bottom
		return;
	}
	
	#For every search term given, seperated by commas:
	foreach my $term (split(/\s*,\s*/, $in)) {
		$output_log->insert('end', "\n");
		
		#The text describing any matches found
		my $result = "";
		
		#Check for gloss word match
		if (exists $gloss_words{$term}) {
			$result .= "   " . gloss_lookup($term);
		}
		
		#Check for gismu match
		if (exists $gihuste{$term}) {
			$result .= "\n" if ($result ne "");
			$result .= "   " . gismu_lookup($term);
		}
		
		#Check for cmavo match
		if (exists $mahoste{$term} || exists $mahoste{"." . $term}) {
			my $key = (exists $mahoste{$term}) ? ($term) : ("." . $term);
			$result .= "\n" if ($result ne "");
			$result .= "   " . cmavo_lookup($key);
		}
		
		#Check for rafsi match
		if (exists $rafste{$term}) { 
			$result .= "\n" if ($result ne "");
			$result .= "   " . rafsi_lookup($term);
		}
		
		#Check for lujvo match
		if (length($term) >= 6 && $term !~ /\s/) {
			#If it is indeed a valid lujvo, report it
			my @words = lujvo_dec($term, 0);
			if (@words) {
				$result .= "\n" if ($result ne "");
				
				#Find the gloss word for each lujvo component
				my @glosses; 
				foreach my $word (@words) {
					if (length($word) == 5)
						{push @glosses, $gihuste{$word}[1];}
					else
						{push @glosses, $mahoste{$word}[1];}
				}
				
				#Display our findings
				$result .= "   Lujvo {" . $term . "}, expanding to {" . join(", ", @words) . "} (" . join(", ", @glosses) . ")";
			}
		}
		
		#Append our results to the output area, or else show an error
		if ($result eq "") {
			$output_log->insert('end', "   No matches for {" . $term . "}");
		} else {
			$entry->delete('0', 'end');
			$output_log->insert('end', $result);
		}
	}

	output_end();
});

#The Def button and associated subroutine
my $def_button = $frame->Button(-text => 'Def', -command => sub {
	output_begin();
	
	#Clean up the input string
	my $in = $entry->get();
	$in =~ /^\s*(.+)\s*$/ or $in = "";
	if ($in ne "") { 
		$in = $1; 
	} else {
		$output_log->insert('end', "\n   No input given.");
		$output_log->yview("moveto", 1); #Scroll down to the bottom
		return;
	}
	
	#For every search term given, seperated by commas:
	foreach my $term (split(/\s*,\s*/, $in)) {
		$output_log->insert('end', "\n");
		
		#The text describing any matches found
		my $result = "";
		
		#Check for gismu matches
		foreach my $gismu (keys(%gihuste)) {
			if ($gihuste{$gismu}[2] =~ /$term/) {
				$result .= "\n" if ($result ne "");
				$result .= "   " . gismu_lookup($gismu);
			}
		}
		
		#Check for cmavo matches
		foreach my $cmavo (keys(%mahoste)) {
			if ($mahoste{$cmavo}[2] =~ /$term/) {
				$result .= "\n" if ($result ne "");
				$result .= "   " . cmavo_lookup($cmavo);
			}
		}
		
		#Append our results to the output area, or else show an error
		if ($result eq "") {
			$output_log->insert('end', "   No matches for {" . $term . "}");
		} else {
			$entry->delete('0', 'end');
			$output_log->insert('end', $result);
		}
	}
	
	output_end();
});

#The Selma'o button and associated subroutine
my $selmaho_button = $frame->Button(-text => "Selma'o", -command => sub {
	output_begin();
	
	#Clean up the input string, and uppercase it since selma'o are uppercase (nobody knows why)
	my $in = uc($entry->get());
	$in =~ /^\s*(.+)\s*$/ or $in = "";
	if ($in ne "") { 
		$in = $1;
	} else {
		$output_log->insert('end', "\n   No input given.");
		$output_log->yview("moveto", 1); #Scroll down to the bottom
		return;
	}
	
	#Lowercase all H's, since this is the selma'o format (nobody knows why)
	$in =~ s/H/h/g;
	
	#For every search term given, seperated by commas:
	foreach my $term (split(/\s*,\s*/, $in)) {
		my $selmaho = ""; #If we find a selma'o, we'll set this to something else
		
		#See if it's already an actual selma'o
		if (exists $selmahoste{$term}) {
			$selmaho = $term;
		} else {
			#If it wasn't a selma'o, maybe it's a cmavo
			my $cmavo = lc($term);
			$cmavo =~ s/h/\'/g;
			$selmaho = $mahoste{$cmavo}[0] if (exists $mahoste{$cmavo});
		}
		
		#If we found a selma'o, print out its members
		if ($selmaho ne "") {
			$entry->delete('0', 'end');
			$output_log->insert('end', "\nSelma'o {" . $selmaho . "} with member cmavo:");
			foreach my $member (@{$selmahoste{$selmaho}}) {
				$output_log->insert('end', "\n   " . $member . " - " . $mahoste{$member}[2]);
			}
		} else {
			$output_log->insert('end', "\n   No such cmavo or selma'o {" . $term . "}");
		}
	}

	output_end();
});

#Pedal to the metal
$entry->pack(-side => 'left', -fill => 'x', -expand => 'y');
$entry->bind('<KeyPress-Return>', sub { $word_button->invoke() });
$word_button->pack(-side => 'left');
$def_button->pack(-side => 'left');
$selmaho_button->pack(-side => 'left');
$frame->pack(-side => 'top', -fill => 'x');
$output_log->pack(-fill => 'both', -expand => 'y');
MainLoop;
