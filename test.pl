# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

# ----------------------------------------------------------------------------

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; }

# Set up an end block to clear the cache when we exit.
END
{
  # Clean up our cache
  Cache::SizeAwareFileCache::Clear($CGI::Cache::CACHE_PATH);
}

use File::Path;
use strict;
use vars qw( %TEST_SCRIPTS $VERSION );

$VERSION = '0.04';

my $PERL = $^X;

# ----------------------------------------------------------------------------

# See below for descriptions
%TEST_SCRIPTS = (
  1 => [<<'EOF',
use lib './blib/lib';
use CGI::Cache;

CGI::Cache::setup();
CGI::Cache::set_key('test key');
CGI::Cache::start() or exit;

print "Test output 1\n";

sleep 2;
EOF
         "Test output 1\n"],

  2 => [<<'EOF',
use lib './blib/lib';
use CGI::Cache;

CGI::Cache::setup( { cache_options => { 
                     filemode => 0666,
                     max_size => 20 * 1024 * 1024,
                     default_expires_in => 6 * 60 * 60,
                   } } );
CGI::Cache::set_key( ['test key 2',1,2] );
CGI::Cache::start() or exit;

print "Test output 2\n";
sleep 2;
EOF
         "Test output 2\n"],

  3 => [<<'EOF',
use lib './blib/lib';
use CGI::Cache;

CGI::Cache::setup( );
CGI::Cache::set_key( {2 => 'test key 3', 1 => 'test', 3 => 'key'} );
CGI::Cache::start() or exit;

print "Test output 3\n";

die "Forced die!" if @ARGV;
EOF
         "Test output 3\n"],

  4 => [<<'EOF',
use lib './blib/lib';
use CGI::Cache;

CGI::Cache::setup( );
CGI::Cache::set_key( {2 => 'test key 3', 1 => 'test', 3 => 'key'} );
CGI::Cache::start() or exit;

print "Test output 4\n";

print STDERR "STDERR!" if @ARGV;
EOF
         "Test output 4\n"],

  5 => [<<'EOF',
use lib './blib/lib';
use CGI::Cache;

CGI::Cache::setup( );
CGI::Cache::set_key( {2 => 'test key 3', 1 => 'test', 3 => 'key'} );
CGI::Cache::start() or exit;

print "Test output 5\n";

CGI::Cache::stop();

print "Test uncached output 5\n";
EOF
         ["Test output 5\n","Test output 5\nTest uncached output 5\n"]],

  6 => [<<'EOF',
use lib './blib/lib';
use CGI::Cache;

$SIG{__DIE__} = sub { print STDOUT @_;exit 1 };

CGI::Cache::setup( );
CGI::Cache::set_key( {2 => 'test key 3', 1 => 'test', 3 => 'key'} );
CGI::Cache::start() or exit;

print "Test output 6\n";

die "STDERR!" if @ARGV;
EOF
         "Test output 6\n"],

  7 => [<<'EOF',
use lib './blib/lib';
use CGI::Cache;

CGI::Cache::setup( { cache_options => {
                     filemode => 0666,
                     max_size => 20 * 1024 * 1024,
                     default_expires_in => 6 * 60 * 60,
                   } } );
CGI::Cache::set_key( ['test key',1,2] );
CGI::Cache::invalidate_cache_entry();
CGI::Cache::start() or exit;

print "Test output 2\n";
EOF
         "Test output 2\n"],

  8 => [<<'EOF',
use lib './blib/lib';
use CGI::Cache;

CGI::Cache::setup();
CGI::Cache::set_key( 'test key' );
CGI::Cache::start() or exit;

print "Test output 1\n";
CGI::Cache::pause();
print "Uncached output\n";
CGI::Cache::continue();
print "Test output 2\n";
EOF
         "Test output 1\nTest output 2\n"],

  9 => [<<'EOF',
use lib './blib/lib';
use CGI::Cache;

open FH, ">TEST.OUT";

CGI::Cache::setup( { output_handle => \*FH } );
CGI::Cache::set_key( 'test key' );
CGI::Cache::start() or die "Should not have cached output for this test\n";

print "Test output 1\n";

CGI::Cache::stop();

close FH;

open FH, "TEST.OUT";
local $/ = undef;
$results = <FH>;
close FH;

unlink "TEST.OUT";

print "RESULTS: $results";
EOF
         "Test output 1\n"],

  10 => [<<'EOF',
use lib './blib/lib';
use CGI::Cache;

CGI::Cache::setup( { watched_output_handle => \*STDOUT,
                     watched_error_handle => \*STDERR,
                     output_handle => \*STDOUT,
                     error_handle => \*STDERR } );
CGI::Cache::set_key('test key');
CGI::Cache::start() or exit;

print "Test output 1\n";

sleep 2;
EOF
         "Test output 1\n"],

  11 => [<<'EOF',
use lib './blib/lib';
use CGI::Cache;

CGI::Cache::setup( { watched_output_handle => \*STDOUT,
                     watched_error_handle => \*STDERR,
                     output_handle => \*STDOUT,
                     error_handle => \*STDERR } );
CGI::Cache::set_key( {2 => 'test key 3', 1 => 'test', 3 => 'key'} );
CGI::Cache::start() or exit;

print "Test output 3\n";

die "Forced die!" if @ARGV;
EOF
         "Test output 3\n"],

  12 => [<<'EOF',
use lib './blib/lib';
use CGI::Cache;

CGI::Cache::setup( { watched_output_handle => \*STDOUT,
                     watched_error_handle => \*STDERR,
                     output_handle => \*STDOUT,
                     error_handle => \*STDERR } );
CGI::Cache::set_key( {2 => 'test key 3', 1 => 'test', 3 => 'key'} );
CGI::Cache::start() or exit;

print "Test output 5\n";

CGI::Cache::stop();

print "Test uncached output 5\n";
EOF
         ["Test output 5\n","Test output 5\nTest uncached output 5\n"]],

  13 => [<<'EOF',
use lib './blib/lib';
use CGI::Cache;

CGI::Cache::setup( { watched_output_handle => \*STDOUT,
                     watched_error_handle => \*STDERR,
                     output_handle => \*STDOUT,
                     error_handle => \*STDERR } );
CGI::Cache::set_key( 'test key' );
CGI::Cache::start() or exit;

print "Test output 1\n";
CGI::Cache::pause();
print "Uncached output\n";
CGI::Cache::continue();
print "Test output 2\n";
EOF
         "Test output 1\nTest output 2\n"],

  14 => [<<'EOF',
use lib './blib/lib';
use CGI::Cache;

open FH, ">TEST.OUT";

CGI::Cache::setup( { watched_output_handle => \*FH } );
CGI::Cache::set_key( 'test key' );
CGI::Cache::start() or die "Should not have cached output for this test\n";

print FH "Test output 1\n";

CGI::Cache::stop();

close FH;

open FH, "TEST.OUT";
local $/ = undef;
$results = <FH>;
close FH;

unlink "TEST.OUT";

print "RESULTS: $results";
EOF
         "Test output 1\n"],

);

# ----------------------------------------------------------------------------

my $tests = get_tests();
my $total = @$tests;

print "1..$total\n";

my $test_number = 1;

foreach my $test (@$tests) {
#$test_number++ and next unless $test_number =~ /^(1|2|11)$/;
	if (&$test) {
		print "ok $test_number\n";
	} else {
		print "not ok $test_number\n";
		print STDERR "$@\n";
	}
	$test_number++;
}

# ----------------------------------------------------------------------------

sub get_tests {
	[

# Test 1: that the module can be loaded without errors
sub {
	unless (eval "require CGI::Cache")
  {
    print "not ok 1\n";
    exit 1;
  }

	1;
},

# Test 2: that we can initialize the cache with the default values
sub {
  my $x;
	$@ = '';

	eval {
	  $x = CGI::Cache::setup();
  };

	(($x == 1) && ($@ eq '')) ? 1 : 0;
},

# Test 3: that we can initialize the cache with the non-default values
sub {
  my $x;
  $@ = '';

	eval {
	  $x = CGI::Cache::setup( { namespace => $0,
                              username => '',
                              filemode => 0666,
                              max_size => 20 * 1024 * 1024,
                              expires_in => 6 * 60 * 60,
                            } );
  };

	(($x == 1) && ($@ eq '')) ? 1 : 0;
},

# Test 4: that we can set a simple key
sub {
  my $x;
  $@ = '';

	eval {
	  $x = CGI::Cache::set_key( 'test1' );
  };

	(($x == 1) && ($@ eq '')) ? 1 : 0;
},

# Test 5: that we can set a complex key
sub {
  my $x;
  $@ = '';

	eval {
	  $x = CGI::Cache::set_key( { 'a' => [0,1,2], 'b' => 'test2'} );
  };

	(($x == 1) && ($@ eq '')) ? 1 : 0;
},

# Test 6: caching with default attributes
sub {
	return time_script(1);
},

# Test 7: caching with some custom attributes, and with a complex data
# structure
sub {
	return time_script(2);
},

# Test 8: that a script with an error doesn't cache output
sub {
  my $script_number = 3;

	my $test_script = "cgi_test_$script_number.cgi";

  write_script($script_number,$test_script);
  setup_cache($script_number,$test_script);

	$@ = '';
	eval {
    # Save STDERR and redirect temporarily to nothing. This will prevent the
    # test script from emitting output to STDERR
    use vars qw(*OLDSTDERR);
    open OLDSTDERR,">&STDERR" or die "Can't save STDERR: $!\n";
    open STDERR,">STDERR-redirected"
      or die "Can't redirect STDERR to STDERR-redirected: $!\n";

		#	First run should die after printing some output
		`$PERL $test_script args`;

    open STDERR,">&OLDSTDERR" or die "Can't restore STDERR: $!\n";

    # Make sure there is nothing in the cache
		die "A script with an error resulted in cached content."
		  if defined $CGI::Cache::THE_CACHE->get($CGI::Cache::THE_CACHE_KEY);

		#	Now run successfully and make sure the cached content is there
		my $script_results_2 = `$PERL $test_script`;

    # Get the real answer and compare that to what test generated
    my $real_results = $TEST_SCRIPTS{$script_number}[1];

		die "Second run of test script didn't return the correct content."
		 if $real_results ne $script_results_2;

		die "Cache file didn't have right content."
		 if $real_results ne $CGI::Cache::THE_CACHE->get($CGI::Cache::THE_CACHE_KEY);
	};

	unlink "$test_script";
	unlink "STDERR-redirected";

	($@ eq '') ? 1 : 0;
},

# Test 9: that a script that prints to STDERR doesn't cache output
sub {
  my $script_number = 4;

	my $test_script = "cgi_test_$script_number.cgi";

  write_script($script_number,$test_script);
  setup_cache($script_number,$test_script);

	$@ = '';
	eval {
    # Save STDERR and redirect temporarily to nothing. This will prevent the
    # test script from emitting output to STDERR
    use vars qw(*OLDSTDERR);
    open OLDSTDERR,">&STDERR" or die "Can't save STDERR: $!\n";
    open STDERR,">STDERR-redirected"
      or die "Can't redirect STDERR to STDERR-redirected: $!\n";

		#	First run should print to STDERR after printing some output
		`$PERL $test_script args`;

    open STDERR,">&OLDSTDERR" or die "Can't restore STDERR: $!\n";

    # Make sure there is nothing in the cache
		die "A script with output to STDERR resulted in cached content."
		  if defined $CGI::Cache::THE_CACHE->get($CGI::Cache::THE_CACHE_KEY);

		#	Now run successfully and make sure the cached content is there
		my $script_results_2 = `$PERL $test_script`;

    # Get the real answer and compare that to what test generated
    my $real_results = $TEST_SCRIPTS{$script_number}[1];

		die "Second run of test script didn't return the correct content."
		  if $real_results ne $script_results_2;

		die "Cache file didn't have right content."
		  if $real_results ne $CGI::Cache::THE_CACHE->get($CGI::Cache::THE_CACHE_KEY);
	};

	unlink "$test_script";
	unlink "STDERR-redirected";

	($@ eq '') ? 1 : 0;
},

# Test 10: that stop() actually stops caching output
sub {
  my $script_number = 5;

	my $test_script = "cgi_test_$script_number.cgi";

  write_script($script_number,$test_script);
  setup_cache($script_number,$test_script);

	$@ = '';
	eval {
		#	First run should print to STDOUT but only cache part of it
		my $script_output = `$PERL $test_script`;

    # Get the real STDOUT and compare that to what test generated
    my $real_output_results = $TEST_SCRIPTS{$script_number}[1][1];

		die "Test script didn't output the correct content to STDOUT."
		  if $real_output_results ne $script_output;

    # Get the real cached data and compare that to what test generated
    my $real_cache_results = $TEST_SCRIPTS{$script_number}[1][0];

		die "Cache file didn't have right content."
		  if $real_cache_results ne $CGI::Cache::THE_CACHE->get($CGI::Cache::THE_CACHE_KEY);
	};

	unlink "$test_script";

	($@ eq '') ? 1 : 0;
},

# Test 11: that a script that calls a redirected die doesn't cache output
sub {
  my $script_number = 6;

	my $test_script = "cgi_test_$script_number.cgi";

  write_script($script_number,$test_script);
  setup_cache($script_number,$test_script);

	$@ = '';
	eval {
    # Save STDERR and redirect temporarily to nothing. This will prevent the
    # test script from emitting output to STDERR
    use vars qw(*OLDSTDERR);
    open OLDSTDERR,">&STDERR" or die "Can't save STDERR: $!\n";
    open STDERR,">STDERR-redirected"
      or die "Can't redirect STDERR to STDERR-redirected: $!\n";

		#	First run should die after printing some output
		`$PERL $test_script args`;

    open STDERR,">&OLDSTDERR" or die "Can't restore STDERR: $!\n";

    # Make sure there is nothing in the cache
		die "A script that called a redirected die() resulted in cached content."
		  if defined $CGI::Cache::THE_CACHE->get($CGI::Cache::THE_CACHE_KEY);

		#	Now run successfully and make sure the cached content is there
		my $script_results_2 = `$PERL $test_script`;

    # Get the real answer and compare that to what test generated
    my $real_results = $TEST_SCRIPTS{$script_number}[1];

		die "Second run of test script didn't return the correct content."
		  if $real_results ne $script_results_2;
	};

	unlink "$test_script";
	unlink "STDERR-redirected";

	($@ eq '') ? 1 : 0;
},

# Test 12: test that invalidate_cache_entry() removes the cache entry
sub {
  my ($script_number,$test_script);

  # Do the first run to set up the cached data
  $script_number = 1;
	$test_script = "cgi_test_$script_number.cgi";

  write_script($script_number,$test_script);
  setup_cache($script_number,$test_script);

	$@ = '';
	eval {
		my $script_results = `perl $test_script`;

    # Get the real answer and compare that to what the script generated
    my $real_results = $TEST_SCRIPTS{$script_number}[1];

		($real_results eq $script_results) ||
			die "Test script didn't compute the right content.";

    # Now compare the real answer to what was cached
		($real_results eq $CGI::Cache::THE_CACHE->get($CGI::Cache::THE_CACHE_KEY)) ||
			die "Cache file didn't have right content.";
  };

	unlink "$test_script";

	return 0 unless $@ eq '';

  # Now run a script that invalidates the previous cached content before
  # printing new cached content
  $script_number = 7;
	$test_script = "cgi_test_$script_number.cgi";

  write_script($script_number,$test_script);
  setup_cache($script_number,$test_script);

	$@ = '';
	eval {
		my $script_results = `perl $test_script`;

    # Get the real answer and compare that to what the script generated
    my $real_results = $TEST_SCRIPTS{$script_number}[1];

		($real_results eq $script_results) ||
			die "Test script didn't compute the right content.";

    # Now compare the real answer to what was cached
		($real_results eq $CGI::Cache::THE_CACHE->get($CGI::Cache::THE_CACHE_KEY)) ||
			die "Cache file didn't have right content.";
	};

	unlink "$test_script";

	($@ eq '') ? 1 : 0;
},

# Test 13: test pause() and continue()
sub {
  my $script_number = 8;
	my $test_script = "cgi_test_$script_number.cgi";

  write_script($script_number,$test_script);
  setup_cache($script_number,$test_script);

	$@ = '';
	eval {
    # Run it once to get the full output but only cache the specified parts.
		`perl $test_script`;

    # Get the real answer and compare that to what the script generated
    my $real_results = $TEST_SCRIPTS{$script_number}[1];

    # Now compare the real answer to what was cached
		($real_results eq $CGI::Cache::THE_CACHE->get($CGI::Cache::THE_CACHE_KEY)) ||
			die "Cache file didn't have right content.";
	};

	unlink "$test_script";

	($@ eq '') ? 1 : 0;
},

# Test 14: test buffer() with multiple arguments
sub {
  my $script_number = 8;
	my $test_script = "cgi_test_$script_number.cgi";

  write_script($script_number,$test_script);
  setup_cache($script_number,$test_script);

	$@ = '';
	eval {
    # Run it once to get the full output but only cache the specified parts.
		`perl $test_script`;

    # Get the real answer and compare that to what the script generated
    my $real_results = $TEST_SCRIPTS{$script_number}[1];

    # Now compare the real answer to what was cached
		($real_results eq $CGI::Cache::THE_CACHE->get($CGI::Cache::THE_CACHE_KEY)) ||
			die "Cache file didn't have right content.";
	};

	unlink "$test_script";

	($@ eq '') ? 1 : 0;
},

# Test 15: caching with default attributes. (set handles)
sub {
	return time_script(10);
},

# Test 16: that a script with an error doesn't cache output. (set handles)
sub {
  my $script_number = 11;

	my $test_script = "cgi_test_$script_number.cgi";

  write_script($script_number,$test_script);
  setup_cache($script_number,$test_script);

	$@ = '';
	eval {
    # Save STDERR and redirect temporarily to nothing. This will prevent the
    # test script from emitting output to STDERR
    use vars qw(*OLDSTDERR);
    open OLDSTDERR,">&STDERR" or die "Can't save STDERR: $!\n";
    open STDERR,">STDERR-redirected"
      or die "Can't redirect STDERR to STDERR-redirected: $!\n";

		#	First run should die after printing some output
		`$PERL $test_script args`;

    open STDERR,">&OLDSTDERR" or die "Can't restore STDERR: $!\n";

    # Make sure there is nothing in the cache
		die "A script with an error resulted in cached content."
		  if defined $CGI::Cache::THE_CACHE->get($CGI::Cache::THE_CACHE_KEY);

		#	Now run successfully and make sure the cached content is there
		my $script_results_2 = `$PERL $test_script`;

    # Get the real answer and compare that to what test generated
    my $real_results = $TEST_SCRIPTS{$script_number}[1];

		die "Second run of test script didn't return the correct content."
		 if $real_results ne $script_results_2;

		die "Cache file didn't have right content."
		 if $real_results ne $CGI::Cache::THE_CACHE->get($CGI::Cache::THE_CACHE_KEY);
	};

	unlink "$test_script";
	unlink "STDERR-redirected";

	($@ eq '') ? 1 : 0;
},

# Test 17: that stop() actually stops caching output. (set handles)
sub {
  my $script_number = 12;

	my $test_script = "cgi_test_$script_number.cgi";

  write_script($script_number,$test_script);
  setup_cache($script_number,$test_script);

	$@ = '';
	eval {
		#	First run should print to STDOUT but only cache part of it
		my $script_output = `$PERL $test_script`;

    # Get the real STDOUT and compare that to what test generated
    my $real_output_results = $TEST_SCRIPTS{$script_number}[1][1];

		die "Test script didn't output the correct content to STDOUT."
		  if $real_output_results ne $script_output;

    # Get the real cached data and compare that to what test generated
    my $real_cache_results = $TEST_SCRIPTS{$script_number}[1][0];

		die "Cache file didn't have right content."
		  if $real_cache_results ne $CGI::Cache::THE_CACHE->get($CGI::Cache::THE_CACHE_KEY);
	};

	unlink "$test_script";

	($@ eq '') ? 1 : 0;
},

# Test 18: test pause() and continue(). (set handles)
sub {
  my $script_number = 13;
	my $test_script = "cgi_test_$script_number.cgi";

  write_script($script_number,$test_script);
  setup_cache($script_number,$test_script);

	$@ = '';
	eval {
    # Run it once to get the full output but only cache the specified parts.
		`perl $test_script`;

    # Get the real answer and compare that to what the script generated
    my $real_results = $TEST_SCRIPTS{$script_number}[1];

    # Now compare the real answer to what was cached
		($real_results eq $CGI::Cache::THE_CACHE->get($CGI::Cache::THE_CACHE_KEY)) ||
			die "Cache file didn't have right content.";
	};

	unlink "$test_script";

	($@ eq '') ? 1 : 0;
},

# Test 19: Output to filehandle other than STDOUT
sub {
  my $script_number = 9;
	my $test_script = "cgi_test_$script_number.cgi";

  write_script($script_number,$test_script);
  setup_cache($script_number,$test_script);

	$@ = '';
	eval {
		my $script_results = `perl $test_script`;

    # Get the real answer and compare that to what the script generated
    my $real_results = $TEST_SCRIPTS{$script_number}[1];

		("RESULTS: $real_results" eq $script_results) ||
			die "Test script didn't compute the right content.";

    # Now compare the real answer to what was cached
		($real_results eq $CGI::Cache::THE_CACHE->get($CGI::Cache::THE_CACHE_KEY)) ||
			die "Cache file didn't have right content.";
	};

	unlink "$test_script";

	($@ eq '') ? 1 : 0;
},

# Test 20: Monitor a filehandle other than STDOUT
sub {
  my $script_number = 14;
	my $test_script = "cgi_test_$script_number.cgi";

  write_script($script_number,$test_script);
  setup_cache($script_number,$test_script);

	$@ = '';
	eval {
		my $script_results = `perl $test_script`;

    # Get the real answer and compare that to what the script generated
    my $real_results = $TEST_SCRIPTS{$script_number}[1];

		("RESULTS: $real_results" eq $script_results) ||
			die "Test script didn't compute the right content.";

    # Now compare the real answer to what was cached
		($real_results eq $CGI::Cache::THE_CACHE->get($CGI::Cache::THE_CACHE_KEY)) ||
			die "Cache file didn't have right content.";
	};

	unlink "$test_script";

	($@ eq '') ? 1 : 0;
},

	];
}

# ----------------------------------------------------------------------------

sub time_script
{
  my $script_number = shift;

	my $test_script = "cgi_test_$script_number.cgi";

  write_script($script_number,$test_script);
  setup_cache($script_number,$test_script);

	$@ = '';
	eval {
		#	First run should take longer & create cache file
		my $t1 = time;

		my $script_results = `$PERL $test_script`;

		$t1 = time - $t1;

    # Get the real answer and compare that to what the script generated
    my $real_results = $TEST_SCRIPTS{$script_number}[1];

		($real_results eq $script_results) ||
			die "Test script didn't compute the right content.";

    # Now compare the real answer to what was cached
		($real_results eq $CGI::Cache::THE_CACHE->get($CGI::Cache::THE_CACHE_KEY)) ||
			die "Cache file didn't have right content.";

		#	Second run should be short, but return output from cache
		my $t2 = time;

		my $script_results_2 = `$PERL $test_script`;

		$t2 = time - $t2;

		($real_results eq $script_results_2) ||
			die "Second run of test script didn't return the correct content.";

		#	Do a cursory check to see that it was at least a little
		#	faster with the cached file, only if $t2 != 0;
		if ($t2 != 0) {
			if ($t1/$t2 < 1.5) {
				die "Caching didn't really speed things up... hmmm...";
			}
		}
	};

	unlink "$test_script";

	($@ eq '') ? 1 : 0;
}

# ----------------------------------------------------------------------------

sub write_script
{
	my $script_number = shift;
	my $test_script = shift;

	open(FH,">$test_script") || die "Can't open file \"$test_script\". $!\n";
	print FH $TEST_SCRIPTS{$script_number}[0];
	close FH;
}

# ----------------------------------------------------------------------------

sub setup_cache
{
  my $script_number = shift;
  my $test_script = shift;

  # Setup the CGI::Cache the same way the test script does so that we
  # can clear the cache and then look at the cached info after the run.
  my ($cache_options) = $TEST_SCRIPTS{$script_number}[0] =~ /setup\((.*?)\)/s;
  my ($cache_key) = $TEST_SCRIPTS{$script_number}[0] =~ /set_key\((.*?)\)/s;

  $ENV{SCRIPT_NAME} = $test_script;

  eval "CGI::Cache::setup($cache_options)";
  eval "CGI::Cache::set_key($cache_key)";

  # Clear the cache to start the test
  $CGI::Cache::THE_CACHE->clear();
}

# ----------------------------------------------------------------------------
