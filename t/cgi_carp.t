use Test::More;

use strict;
use lib 't';
use Test::Utils;
use File::Path;
use CGI::Cache;

use vars qw( $VERSION );

$VERSION = sprintf "%d.%02d%02d", q/0.10.0/ =~ /(\d+)/g;

# ----------------------------------------------------------------------------

unless(eval 'require CGI::Carp')
{
  plan skip_all => 'CGI::Carp not installed';
  exit;
}

plan tests => 7;

# ----------------------------------------------------------------------------

# Make sure the cache directory isn't there
rmtree 't/CGI_Cache_tempdir';

# ----------------------------------------------------------------------------

my $script_number = 1;

# ----------------------------------------------------------------------------

# Test 1-3: caching with default attributes
{
my $test_script_name = "t/cgi_test_$script_number.cgi";

my $script = <<'EOF';
use lib '../blib/lib';
use CGI::Cache;
use CGI::Carp qw(fatalsToBrowser set_message);

CGI::Cache::setup({ cache_options => { cache_root => 't/CGI_Cache_tempdir' } });
CGI::Cache::set_key('test key');
CGI::Cache::start() or exit;

die ("Good day to die\n");
EOF

my ($short_script_name) = $test_script_name =~ /.*\/(.*)$/;

my $expected_stdout = qr/Content-type: text\/html.*<pre>Good day to die/si;
my $expected_stderr = qr/\[[^\]]+:[^\]]+\] $short_script_name: Good day to die/si;
my $expected_cached = undef;
my $message = "CGI::Carp not caching with default attributes";

Run_Script($test_script_name, $script, $expected_stdout, $expected_stderr,
$expected_cached, $message, 1);

$script_number++;
}

# ----------------------------------------------------------------------------

# Test 4: There should be no cache directory until we actually cache something
ok(!-e 't/CGI_Cache_tempdir', 'No cache directory until something cached');

# ----------------------------------------------------------------------------

# Test 5-7: caching with default attributes
{
my $test_script_name = "t/cgi_test_$script_number.cgi";

my $script = <<'EOF';
use lib '../blib/lib';
use CGI::Cache;
use CGI::Carp qw(fatalsToBrowser set_message);

CGI::Cache::setup({ cache_options => { cache_root => 't/CGI_Cache_tempdir' } });
CGI::Cache::set_key('test key');
CGI::Cache::start() or exit;

print ("Good day to live\n");
EOF

my $expected_stdout = "Good day to live\n";
my $expected_stderr = '';
my $expected_cached = "Good day to live\n";
my $message = "CGI::Carp caching with default attributes";

Run_Script($test_script_name, $script, $expected_stdout, $expected_stderr,
$expected_cached, $message, 1);

$script_number++;
}

# ----------------------------------------------------------------------------

# Cleanup
rmtree 't/CGI_Cache_tempdir';
