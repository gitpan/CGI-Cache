use Test::More tests => 9;

use strict;
use lib 't';
use Test::Utils;
use File::Path;
use CGI::Cache;

use vars qw( $VERSION );

$VERSION = sprintf "%d.%02d%02d", q/0.10.0/ =~ /(\d+)/g;

# ----------------------------------------------------------------------------

# Make sure the cache directory isn't there
rmtree 't/CGI_Cache_tempdir';

# ----------------------------------------------------------------------------

sub Time_Script
{
  my $script = shift;
  my $expected_stdout = shift;
  my $message = shift; 
  
  my $test_script_name = "t/cgi_test.cgi";
  
  #  First run should take longer & create cache file
  my $t1 = time;
  
  Run_Script($test_script_name, $script, $expected_stdout, undef, undef,
    "$message (first run)");
  
  $t1 = time - $t1;
    
    
  #  Second run should be short, but return output from cache
  my $t2 = time;

  Run_Script($test_script_name, $script, $expected_stdout, undef, undef,
    "$message (second run)");

  $t2 = time - $t2;

  #  Do a cursory check to see that it was at least a little
  #  faster with the cached file, only if $t2 != 0;
  SKIP: {
    skip "Both runs were too fast to compare", 1 if $t2 == 0 && $t1 == 0;

    ok($t2 == 0 || $t1/$t2 < 1.5, "$message: Caching run was faster");
  }
}

# ---------------------------------------------------------------------------

# Test 1-4: caching with default attributes
Time_Script(<<EOF,"Test output 1\n","Default attributes");
use lib '../blib/lib';
use CGI::Cache;

CGI::Cache::setup({ cache_options => { cache_root => 't/CGI_Cache_tempdir' } });
CGI::Cache::set_key('test key');
CGI::Cache::start() or exit;

print "Test output 1\n";

sleep 2;
EOF

# Clean up
rmtree 't/CGI_Cache_tempdir';

# ----------------------------------------------------------------------------

# Test 5-8: caching with some custom attributes, and with a complex data
# structure
Time_Script(<<EOF,"Test output 2\n","Custom attributes");
use lib '../blib/lib';
use CGI::Cache;

CGI::Cache::setup( { cache_options => { 
                     cache_root => 't/CGI_Cache_tempdir',
                     filemode => 0666,
                     max_size => 20 * 1024 * 1024,
                     default_expires_in => 6 * 60 * 60,
                   } } );
CGI::Cache::set_key( ['test key 2',1,2] );
CGI::Cache::start() or exit;

print "Test output 2\n";
sleep 2;
EOF

# Clean up
rmtree 't/CGI_Cache_tempdir';

# ----------------------------------------------------------------------------

# Test 9-12: caching with default attributes. (set handles)
Time_Script(<<EOF,"Test output 1\n","Set handles");
use lib '../blib/lib';
use CGI::Cache;

CGI::Cache::setup( { cache_options => { cache_root => 't/CGI_Cache_tempdir' },
                     watched_output_handle => \*STDOUT,
                     watched_error_handle => \*STDERR,
                     output_handle => \*STDOUT,
                     error_handle => \*STDERR } );
CGI::Cache::set_key('test key');
CGI::Cache::start() or exit;

print "Test output 1\n";

sleep 2;
EOF

# Clean up
rmtree 't/CGI_Cache_tempdir';
