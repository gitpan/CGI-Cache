use Test::More tests => 6;

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

# Test 1-3: that stop() actually stops caching output
{
my $test_script_name = "t/cgi_test_$script_number.cgi";

my $script = <<'EOF';
use lib '../blib/lib';
use CGI::Cache;

CGI::Cache::setup({ cache_options => { cache_root => 't/CGI_Cache_tempdir' } });
CGI::Cache::set_key( {2 => 'test key 3', 1 => 'test', 3 => 'key'} );
CGI::Cache::start() or exit;

print "Test output 5\n";

CGI::Cache::stop();

print "Test uncached output 5\n";
EOF

my $expected_stdout = "Test output 5\nTest uncached output 5\n";
my $expected_stderr = '';
my $expected_cached = "Test output 5\n";
my $message = 'stop()';

Run_Script($test_script_name, $script, $expected_stdout, $expected_stderr,
  $expected_cached, $message, 1);

$script_number++;

rmtree 't/CGI_Cache_tempdir';
}

# ----------------------------------------------------------------------------

# Test 4-6: that stop() actually stops caching output. (set handles)
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

print "Test output 5\n";

CGI::Cache::stop();

print "Test uncached output 5\n";
EOF

my $expected_stdout = "Test output 5\nTest uncached output 5\n";
my $expected_stderr = '';
my $expected_cached = "Test output 5\n";
my $message = 'stop() with filehandles';

Run_Script($test_script_name, $script, $expected_stdout, $expected_stderr,
  $expected_cached, $message, 1);

$script_number++;

rmtree 't/CGI_Cache_tempdir';
}

# ----------------------------------------------------------------------------

