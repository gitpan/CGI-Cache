use Test::More tests => 3;

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

# Test 1-3: test disabling of output while caching
{
my $test_script_name = "t/cgi_test_$script_number.cgi";

my $script = <<'EOF';
use lib '../blib/lib';
use CGI::Cache;

CGI::Cache::setup( { cache_options => { cache_root => 't/CGI_Cache_tempdir' },
                     enable_output => 0 } );
CGI::Cache::set_key('test key');
CGI::Cache::start() or exit;

print "Test output 1\n";

sleep 2;
EOF

my $expected_stdout = "";
my $expected_stderr = '';
my $expected_cached = "Test output 1\n";
my $message = 'Disabled output';

Run_Script($test_script_name, $script, $expected_stdout, $expected_stderr,
  $expected_cached, $message);

$script_number++;

rmtree 't/CGI_Cache_tempdir';
}
