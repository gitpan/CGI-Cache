# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; }
END {print "not ok 1\n" unless $loaded;}
use CGI::Cache;
use File::Path;

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

my $TMPDIR = '/tmp/cgi-cache';

my $tests = get_tests();
my $total = @$tests;
print "1..$total\n";
my $test_number = 1;
my $x, $test;
for $test (@$tests) {
	if (&$test) {
		print "ok $test_number\n";
	} else {
		print "not ok $test_number\n";
		print STDERR "$@\n";
	}
	$test_number++;
}




sub get_tests {
	[

sub {
	$loaded = 1;
	1;
},

sub {
	$x = CGI::Cache::SetRoot('not_an_abs_path'); # should return 0
	($x==0) ? 1 : 0;
},

sub {
	$@ = '';
	eval {
		CGI::Cache::SetRoot($TMPDIR)|| die 'SetRoot() - failed';
		(-d $TMPDIR)				|| die 'SetRoot() - dir not made';
		(0777 == (0777 & (stat $TMPDIR)[2]))
									|| die 'SetRoot() - wrong dir mode';
		rmtree $TMPDIR;
	};
	return 0 if ($@ ne '');
	1;
},

sub {
	$@ = '';
	eval {
		CGI::Cache::SetRoot($TMPDIR,0755)
									|| die 'SetRoot() - failed';
		(-d $TMPDIR)				|| die 'SetRoot() - dir not made';
		(0755 == (0777 & (stat $TMPDIR)[2]))
									|| die 'SetRoot() - wrong dir mode';
		rmtree $TMPDIR;
	};
	return 0 if ($@ ne '');
	1;
},

##
#	test mkpath not being called with dir already exists
##
sub {
	mkpath $TMPDIR;
	$x = CGI::Cache::SetRoot($TMPDIR,0);	# should succeed
	rmtree $TMPDIR;
	($x == 1) ? 1 : 0;
},

##
#	test mkpath not being called with dir already exists
##
sub {
	$x = CGI::Cache::SetRoot($TMPDIR,0);	# should fail
	($x == 0) ? 1 : 0;
},



##
#	checkout the SetFile() call...
##
sub {
	$@ = '';
	eval {
		CGI::Cache::SetRoot($TMPDIR) || die "SetRoot(0 - failed";
		CGI::Cache::SetFile("thing",60) || die "SetFile() - failed";
		rmtree($TMPDIR);
	};
	return 0 if ($@ ne "");
	1;
},

sub {
	$@ = '';
	eval {
		CGI::Cache::SetFile("/tmp/this/thing") || die "SetFile() - failed";
		(-d "/tmp/this") || die "SetFile() - directory not created";
		rmtree("/tmp/this");
	};
	return 0 if ($@ ne "");
	1;
},


sub {
	$@ = '';
	eval {
		CGI::Cache::SetRoot($TMPDIR) || die "SetRoot() - failed";
		CGI::Cache::SetFile("thing/extra") || die "SetFile() - failed";
		(-d "$TMPDIR/thing") || die "SetFile() - directory not created";
		rmtree("$TMPDIR/thing");
	};
	return 0 if ($@ ne "");
	1;
},

sub {
	$@ = '';
	eval {
		CGI::Cache::SetRoot($TMPDIR) || die "SetRoot() - failed";
		CGI::Cache::SetFile("/tmp/thing/extra") || die "SetFile() - failed";
		(-d "/tmp/thing") || die "SetFile() - dir not created";
		rmtree($TMPDIR);
		rmtree("/tmp/thing");
	};
	return 0 if ($@ ne "");
	1;
},


sub {
	#return 1;
	fib_to_file("fib.model");
	cgi_to_file("test.cgi");

	$@ = '';
	eval {
		my $t0,$t1;
		my $tu, $ts;

		##
		#	first run should take longer & create cache file
		##
		($tu,$ts) = (times)[2,3];
		$t0 = $tu + $ts;
		system "perl test.cgi > fib.out";
		($tu,$ts) = (times)[2,3];
		$t0 = ($tu+$ts) - $t0;
		(0 == compare_files("fib.model","fib.cache")) ||
			die "Cache file didn't have right content.";
		(0 == compare_files("fib.model","fib.out")) ||
			die "CGI STDOUT didn't have right content.";

		##
		#	second run should be short, but return output from cache
		##
		($tu,$ts) = (times)[2,3];
		$t1 = $tu + $ts;
		system "perl test.cgi > fib.out2";
		($tu,$ts) = (times)[2,3];
		$t1 = ($tu+$ts) - $t1;
		(0 == compare_files("fib.out2","fib.out")) ||
			die "CGI STDOUT didn't return the same output content.";

		##
		#	do a cursory check to see that it was at least a little
		#	faster with the cached file, only if $t1 != 0;
		##
		if ($t1 != 0) {
			my $r = ($t0/$t1);
			if ($r < 1.5) {
				die "Caching didn't really speed things up... hmmm...";
			}
		}
	};
	unlink "fib.model", "fib.cache", "fib.out", "fib.out2", "test.cgi";
	if ($@ ne '') {
		return 0;
	}

	1;
},


sub {
	my $tmpdir = "${TMPDIR}2";
	my $A = 4;
	my $B = $A + 2;
	my $S = 2;
	my $Z = ($S * $A) - 2 + $B;

	$@ = '';
	eval {

	mkpath($tmpdir);

	my $i, $j;
	for $i (0..($S-1)) {
		for $j (0..2) {
			my $x = $i*3+$j;
			open  FH, ">$tmpdir/extra.$x" || die "Can't create tmp file. $!\n";
			print FH "This is a test! ($x)\n";
			close FH;
		}
		sleep $A;
	}

	sleep $B;

	CGI::Cache::SetRoot($tmpdir) || die "SetRoot() - failed";
	my @files = CGI::Cache::ExpireLRU(1000);
	die "ExpireLRU failed by removing when it should not.\n" if scalar(@files);

	@files = CGI::Cache::ExpireLRU($Z);
	my @answer = qw ( extra.0 extra.1 extra.2 );
	my $files  = join ':', @files;
	my $answer = join ':', @answer;

	die "ExpireLRU gave wrong answer.\n" if ($files ne $answer);

	rmtree($tmpdir);

	};
	return 0 if ($@ ne "");
	1;
},




	];
}


sub fib {
	my $n = shift;
	return 1 if ($n <= 1);
	return (fib($n-2)+fib($n-1));
}

sub compare_files {
	my($file1,$file2) = @_;
	my $result = 0;
	open(FH1,$file1) || die "1 Can't open file \"$file1\". $!\n";
	open(FH2,$file2) || die "2 Can't open file \"$file2\". $!\n";
	while (<FH1>) {
		my $compare = <FH2>;
		$result = -1 unless ($_ eq $compare);
	}
	return -1 if (<FH2>);	# file was longer than the other
	close FH2;
	close FH1;
	return $result;
}

sub fib_to_file {
	my $file = shift;
	open(FH,">$file") || die "3 Can't open file \"$file\". $!\n";
	for (0..20) {
		my $f = fib($_);
		print FH "$_ -> $f\n";
	}
	close FH;
}

sub cgi_to_file {
	my $file = shift;
	my $code = _really_terrible_cgi_code();
	open(FH,">$file") || die "4 Can't open file \"$file\". $!\n";
	print FH $code;
	close FH;
}


sub _really_terrible_cgi_code {
	my $code =<< '_CODE_';

use lib './blib/lib';
use CGI::Cache;

CGI::Cache::Start("fib.cache");

for (0..20) {
	my $f = fib($_);
	print "$_ -> $f\n";
}

sub fib {
	my $n = shift;
	return 1 if ($n <= 1);
	return (fib($n-2)+fib($n-1));
}

_CODE_

	return $code;
}




