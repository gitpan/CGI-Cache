package Test::Utils;

use strict;
use Exporter;
use Test::More;
use FileHandle;

use vars qw( @EXPORT @ISA $VERSION );

$VERSION = sprintf "%d.%02d%02d", q/0.10.0/ =~ /(\d+)/g;

@ISA = qw( Exporter );
@EXPORT = qw( Run_Script Write_Script Setup_Cache );

# ---------------------------------------------------------------------------

# If any of the expected_ variables are undef, they won't be checked. For
# $expected_cached, use the string "<UNDEF>" to actually check for a value of
# undef.

sub Run_Script
{
  my $test_script_name = shift;
  my $script = shift;
  my $expected_stdout = shift;
  my $expected_stderr = shift;
  my $expected_cached = shift;
  my $message = shift;
  my $clear_cache = shift;

  local $Test::Builder::Level = 2;

  Write_Script($test_script_name,$script);
  Setup_Cache($test_script_name,$script,$clear_cache);

  # Save STDERR and redirect temporarily to nothing. This will prevent the
  # test script from emitting output to STDERR
  {
    use vars qw(*OLDSTDERR);
    open OLDSTDERR,">&STDERR" or die "Can't save STDERR: $!\n";
    open STDERR,">STDERR-redirected"
      or die "Can't redirect STDERR to STDERR-redirected: $!\n";

    my $script_results = `$^X $test_script_name`;
    
    unlink $test_script_name;

    open STDERR,">&OLDSTDERR" or die "Can't restore STDERR: $!\n";

    # Check the answer that the test generated
    if (defined $expected_stdout)
    {
      if (ref $expected_stdout eq 'Regexp')
      {
        like($script_results, $expected_stdout, "$message: Computing the right output");
      }
      else
      {
        is($script_results, $expected_stdout, "$message: Computing the right output");
      }
    }
  }

  {
    open ERROR, "STDERR-redirected";
    local $/ = undef;
    my $script_errors = <ERROR>;
    close ERROR;
    unlink "STDERR-redirected";

    if (defined $expected_stderr)
    {
      if (ref $expected_stderr eq 'Regexp')
      {
        like($script_errors, $expected_stderr, "$message: Computing the right errors");
      }
      else
      {
        is($script_errors, $expected_stderr, "$message: Computing the right errors");
      }
    }
  }

  {
    my $cached_results = $CGI::Cache::THE_CACHE->get($CGI::Cache::THE_CACHE_KEY);

    if (defined $expected_cached)
    {
      if ($expected_cached eq '<UNDEF>')
      {
        ok(!defined($cached_results), "$message: Undefined cached data");
      }
      elsif (ref $expected_cached eq 'Regexp')
      {
        like($cached_results, $expected_cached, "$message: Correct cached data");
      }
      else
      {
        is($cached_results, $expected_cached, "$message: Correct cached data");
      }
    }
  }

  unlink $test_script_name;
}

# ----------------------------------------------------------------------------

sub Write_Script
{
  my $test_script_name = shift;
  my $script = shift;

  open(FH,">$test_script_name") || die "Can't open file \"$test_script_name\". $!\n";
  print FH $script;
  close FH;
}

# ----------------------------------------------------------------------------

sub Setup_Cache
{
  my $test_script_name = shift;
  my $script = shift;
  my $clear_cache = shift;

  # Setup the CGI::Cache the same way the test script does so that we
  # can clear the cache and then look at the cached info after the run.
  my ($cache_options) = $script =~ /setup\((.*?)\)/s;
  my ($cache_key) = $script =~ /set_key\((.*?)\)/s;

  $ENV{SCRIPT_NAME} = $test_script_name;

  eval "CGI::Cache::setup($cache_options)";
  eval "CGI::Cache::set_key($cache_key)";

  # Clear the cache to start the test
  $CGI::Cache::THE_CACHE->clear() if $clear_cache;
}

# ----------------------------------------------------------------------------

1;
