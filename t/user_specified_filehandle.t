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

# Test 1-3: Output to filehandle other than STDOUT
{
my $test_script_name = "t/cgi_test_$script_number.cgi";

my $script = <<'EOF';
use lib '../blib/lib';
use CGI::Cache;

open FH, ">TEST.OUT";

CGI::Cache::setup({ cache_options => { cache_root => 't/CGI_Cache_tempdir' },
                    output_handle => \*FH } );
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

Write_Script($test_script_name,$script);
Setup_Cache($test_script_name,$script);

my $expected_stdout = "RESULTS: Test output 1\n";
my $expected_stderr = '';
my $expected_cached = "Test output 1\n";
my $message = 'Output to non-STDOUT filehandle';

Run_Script($test_script_name, $script, $expected_stdout, $expected_stderr,
  $expected_cached, $message);

$script_number++;

rmtree 't/CGI_Cache_tempdir';
}

# ----------------------------------------------------------------------------

# Test 4-6: Monitor a filehandle other than STDOUT
{
my $test_script_name = "t/cgi_test_$script_number.cgi";

my $script = <<'EOF';
use lib '../blib/lib';
use CGI::Cache;

open FH, ">TEST.OUT";

CGI::Cache::setup( { cache_options => { cache_root => 't/CGI_Cache_tempdir' },
                     watched_output_handle => \*FH } );
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

my $expected_stdout = "RESULTS: Test output 1\n";
my $expected_stderr = '';
my $expected_cached = "Test output 1\n";
my $message = 'Monitor non-STDOUT filehandle';

Run_Script($test_script_name, $script, $expected_stdout, $expected_stderr,
  $expected_cached, $message);

$script_number++;

rmtree 't/CGI_Cache_tempdir';
}
