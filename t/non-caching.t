use Test::More tests => 16;

use strict;
use lib 't';
use File::Path;
use Test::Utils;
use CGI::Cache;

use vars qw( $VERSION );

$VERSION = sprintf "%d.%02d%02d", q/0.10.0/ =~ /(\d+)/g;

# ----------------------------------------------------------------------------

# Make sure the cache directory isn't there
rmtree 't/CGI_Cache_tempdir';

# ----------------------------------------------------------------------------

my $script_number = 1;

# ----------------------------------------------------------------------------

# Tests 1-3: that a script with an error doesn't cache output
{
my $test_script_name = "t/cgi_test_$script_number.cgi";

my $script = <<'EOF';
use lib '../blib/lib';
use CGI::Cache;

CGI::Cache::setup({ cache_options => { cache_root => 't/CGI_Cache_tempdir' } });
CGI::Cache::set_key( {2 => 'test key 3', 1 => 'test', 3 => 'key'} );
CGI::Cache::start() or exit;

print "Test output 1\n";

die "Forced die!\n";
EOF

my $expected_stdout = "Test output 1\n";
my $expected_stderr = "Forced die!\n";
my $expected_cached = '<UNDEF>';
my $message = 'die() prevents caching';

Run_Script($test_script_name, $script, $expected_stdout, $expected_stderr,
  $expected_cached, $message, 1);

$script_number++;

rmtree 't/CGI_Cache_tempdir';
}

# ----------------------------------------------------------------------------

# Test 4: There should be no cache directory until we actually cache something
ok(!-e 't/CGI_Cache_tempdir', 'No cache directory until something cached');

# ----------------------------------------------------------------------------

# Test 5-7: that a script that prints to STDERR doesn't cache output
{
my $test_script_name = "t/cgi_test_$script_number.cgi";

my $script = <<'EOF';
use lib '../blib/lib';
use CGI::Cache;

CGI::Cache::setup( { cache_options => { cache_root => 't/CGI_Cache_tempdir' } } );
CGI::Cache::set_key( {2 => 'test key 3', 1 => 'test', 3 => 'key'} );
CGI::Cache::start() or exit;

print "Test output 1\n";

print STDERR "STDERR!\n";
EOF

my $expected_stdout = "Test output 1\n";
my $expected_stderr = "STDERR!\n";
my $expected_cached = '<UNDEF>';
my $message = 'Print to STDERR prevents caching';

Run_Script($test_script_name, $script, $expected_stdout, $expected_stderr,
  $expected_cached, $message, 1);

$script_number++;

rmtree 't/CGI_Cache_tempdir';
}

# ----------------------------------------------------------------------------

# Test 8: There should be no cache directory until we actually cache something
ok(!-e 't/CGI_Cache_tempdir', 'No cache directory until something cached');

# ----------------------------------------------------------------------------

# Tests 9-11: that a script that calls a redirected die doesn't cache output
{
my $test_script_name = "t/cgi_test_$script_number.cgi";

my $script = <<'EOF';
use lib '../blib/lib';
use CGI::Cache;

$SIG{__DIE__} = sub { print STDOUT @_;exit 1 };

CGI::Cache::setup( { cache_options => { cache_root => 't/CGI_Cache_tempdir' } } );
CGI::Cache::set_key( {2 => 'test key 3', 1 => 'test', 3 => 'key'} );
CGI::Cache::start() or exit;

print "Test output 1\n";

die "STDERR!\n";
EOF

my $expected_stdout = "Test output 1\nSTDERR!\n";
my $expected_stderr = "";
my $expected_cached = '<UNDEF>';
my $message = 'redirected die() prevents caching';

Run_Script($test_script_name, $script, $expected_stdout, $expected_stderr,
  $expected_cached, $message, 1);

$script_number++;

rmtree 't/CGI_Cache_tempdir';
}

# ----------------------------------------------------------------------------

# Test 12: There should be no cache directory until we actually cache something
ok(!-e 't/CGI_Cache_tempdir', 'No cache directory until something cached');

# ----------------------------------------------------------------------------

# Test 13-15: that a script with an error doesn't cache output. (set handles)
{
my $test_script_name = "t/cgi_test_$script_number.cgi";

my $script = <<'EOF';
use lib '../blib/lib';
use CGI::Cache;

CGI::Cache::setup( { cache_options => { cache_root => 't/CGI_Cache_tempdir' },
                     watched_output_handle => \*STDOUT,
                     watched_error_handle => \*STDERR,
                     output_handle => \*STDOUT,
                     error_handle => \*STDERR } );
CGI::Cache::set_key( {2 => 'test key 3', 1 => 'test', 3 => 'key'} );
CGI::Cache::start() or exit;

print "Test output 1\n";

die "Forced die!\n";
EOF

my $expected_stdout = "Test output 1\n";
my $expected_stderr = "Forced die!\n";
my $expected_cached = '<UNDEF>';
my $message = 'die() (with filehandles) prevents caching';

Run_Script($test_script_name, $script, $expected_stdout, $expected_stderr,
  $expected_cached, $message, 1);

$script_number++;

rmtree 't/CGI_Cache_tempdir';
}

# ----------------------------------------------------------------------------

# Test 16: There should be no cache directory until we actually cache something
ok(!-e 't/CGI_Cache_tempdir', 'No cache directory until something cached');

# ----------------------------------------------------------------------------
