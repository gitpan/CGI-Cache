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
  File::Cache::CLEAR($CGI::Cache::CACHE_PATH);
}

use File::Path;
use strict;
use vars qw( %TEST_SCRIPTS $VERSION );

$VERSION = '0.01';

# ----------------------------------------------------------------------------

%TEST_SCRIPTS = (
  1 => [<<'EOF',
use lib './blib/lib';
use CGI::Cache;

CGI::Cache::setup();
CGI::Cache::set_key('test key');
CGI::Cache::start();

print "Test output 1\n";

sleep 2;
EOF
         "Test output 1\n"],

  2 => [<<'EOF',
use lib './blib/lib';
use CGI::Cache;

CGI::Cache::setup( { username => '',
                     filemode => 0666,
                     max_size => 20 * 1024 * 1024,
                     expires_in => 6 * 60 * 60,
                   } );
CGI::Cache::set_key( ['test key 2',1,2] );
CGI::Cache::start();

print "Test output 2\n";
sleep 2;
EOF
         "Test output 2\n"],

  3 => [<<'EOF',
use lib './blib/lib';
use CGI::Cache;

CGI::Cache::setup( );
CGI::Cache::set_key( {2 => 'test key 3', 1 => 'test', 3 => 'key'} );
CGI::Cache::start();

print "Test output 3\n";

die "Forced die!" if @ARGV;
EOF
         "Test output 3\n"],

  4 => [<<'EOF',
use lib './blib/lib';
use CGI::Cache;

CGI::Cache::setup( );
CGI::Cache::set_key( {2 => 'test key 3', 1 => 'test', 3 => 'key'} );
CGI::Cache::start();

print "Test output 4\n";

print STDERR "STDERR!" if @ARGV;
EOF
         "Test output 4\n"],
);

# ----------------------------------------------------------------------------

my $tests = get_tests();
my $total = @$tests;

print "1..$total\n";

my $test_number = 1;

foreach my $test (@$tests) {
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

# Test that module can be loaded without errors
sub {
	unless (eval "require CGI::Cache")
  {
    print "not ok 1\n";
    exit 1;
  }

	1;
},

# Test that we can initialize the cache with the default values
sub {
  my $x;
	$@ = '';

	eval {
	  $x = CGI::Cache::setup();
  };

	(($x == 1) && ($@ eq '')) ? 1 : 0;
},

# Test that we can initialize the cache with the non-default values
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

# Test that we can set a simple key
sub {
  my $x;
  $@ = '';

	eval {
	  $x = CGI::Cache::set_key( 'test1' );
  };

	(($x == 1) && ($@ eq '')) ? 1 : 0;
},

# Test that we can set a complex key
sub {
  my $x;
  $@ = '';

	eval {
	  $x = CGI::Cache::set_key( { 'a' => [0,1,2], 'b' => 'test2'} );
  };

	(($x == 1) && ($@ eq '')) ? 1 : 0;
},

# Test caching with default attributes
sub {
	return time_script(1);
},

# Test caching with some custom attributes, and with a complex data structure
sub {
	return time_script(2);
},

# Test that a script with an error doesn't cache output
sub {
  my $script_number = 3;

	my $file = "cgi_test_$script_number.cgi";

  write_script($script_number,$file);
  setup_cache($script_number,$file);

	$@ = '';
	eval {
    # Save STDERR and redirect temporarily to nothing. This will prevent the
    # test script from emitting output to STDERR
    use vars qw(*OLDSTDERR);
    open OLDSTDERR,">&STDERR" or die "Can't save STDERR: $!\n";
    open STDERR,">STDERR-redirected"
      or die "Can't redirect STDERR to STDERR-redirected: $!\n";

		#	First run should die after printing some output
		`perl $file args`;

    open STDERR,">&OLDSTDERR" or die "Can't restore STDERR: $!\n";

    # Make sure there is nothing in the cache
		(!defined $CGI::Cache::CACHE->get($CGI::Cache::CACHE_KEY)) ||
			die "A script with an error resulted in cached content.";

		#	Now run successfully and make sure the cached content is there
		my $script_results_2 = `perl $file`;

    # Get the real answer and compare that to what test generated
    my $real_results = $TEST_SCRIPTS{$script_number}[1];

		($real_results eq $script_results_2) ||
			die "Second run of test script didn't return the correct content.";

		($real_results eq $CGI::Cache::CACHE->get($CGI::Cache::CACHE_KEY)) ||
			die "Cache file didn't have right content.";
	};

	unlink "$file";
	unlink "STDERR-redirected";

	($@ eq '') ? 1 : 0;
},

# Test that a script that prints to STDERR doesn't cache output
sub {
  my $script_number = 4;

	my $file = "cgi_test_$script_number.cgi";

  write_script($script_number,$file);
  setup_cache($script_number,$file);

	$@ = '';
	eval {
    # Save STDERR and redirect temporarily to nothing. This will prevent the
    # test script from emitting output to STDERR
    use vars qw(*OLDSTDERR);
    open OLDSTDERR,">&STDERR" or die "Can't save STDERR: $!\n";
    open STDERR,">STDERR-redirected"
      or die "Can't redirect STDERR to STDERR-redirected: $!\n";

		#	First run should print to STDERR after printing some output
		`perl $file args`;

    open STDERR,">&OLDSTDERR" or die "Can't restore STDERR: $!\n";

    # Make sure there is nothing in the cache
		(!defined $CGI::Cache::CACHE->get($CGI::Cache::CACHE_KEY)) ||
			die "A script with output to STDERR resulted in cached content.";

		#	Now run successfully and make sure the cached content is there
		my $script_results_2 = `perl $file`;

    # Get the real answer and compare that to what test generated
    my $real_results = $TEST_SCRIPTS{$script_number}[1];

		($real_results eq $script_results_2) ||
			die "Second run of test script didn't return the correct content.";

		($real_results eq $CGI::Cache::CACHE->get($CGI::Cache::CACHE_KEY)) ||
			die "Cache file didn't have right content.";
	};

	unlink "$file";
	unlink "STDERR-redirected";

	($@ eq '') ? 1 : 0;
},

	];
}

# ----------------------------------------------------------------------------

sub time_script
{
  my $script_number = shift;

	my $file = "cgi_test_$script_number.cgi";

  write_script($script_number,$file);
  setup_cache($script_number,$file);

	$@ = '';
	eval {
		#	First run should take longer & create cache file
		my $t1 = time;

		my $script_results = `perl $file`;

		$t1 = time - $t1;

    # Get the real answer and compare that to what the script generated
    my $real_results = $TEST_SCRIPTS{$script_number}[1];

		($real_results eq $script_results) ||
			die "Test script didn't compute the right content.";

    # Now compare the real answer to what was cached
		($real_results eq $CGI::Cache::CACHE->get($CGI::Cache::CACHE_KEY)) ||
			die "Cache file didn't have right content.";

		#	Second run should be short, but return output from cache
		my $t2 = time;

		my $script_results_2 = `perl $file`;

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

	unlink "$file";

	($@ eq '') ? 1 : 0;
}

# ----------------------------------------------------------------------------

sub write_script
{
	my $script_number = shift;
	my $file = shift;

	open(FH,">$file") || die "Can't open file \"$file\". $!\n";
	print FH $TEST_SCRIPTS{$script_number}[0];
	close FH;
}

# ----------------------------------------------------------------------------

sub setup_cache
{
  my $script_number = shift;
  my $file = shift;

  # Setup the CGI::Cache the same way the test script does so that we
  # can clear the cache and then look at the cached info after the run.
  my ($cache_options) = $TEST_SCRIPTS{$script_number}[0] =~ /setup\((.*?)\)/s;
  my ($cache_key) = $TEST_SCRIPTS{$script_number}[0] =~ /set_key\((.*?)\)/s;

  $ENV{SCRIPT_NAME} = $file;
  eval "CGI::Cache::setup($cache_options)";
  eval "CGI::Cache::set_key($cache_key)";

  # Clear the cache to start the test
  $CGI::Cache::CACHE->clear();
}

# ----------------------------------------------------------------------------
