package CGI::Cache;

use strict;
use vars qw( $VERSION );

use File::Path;
use File::Spec;
use File::Spec::Functions qw( tmpdir );
use File::Cache;
use Storable qw (freeze);

$VERSION = '1.02';

# --------------------------------------------------------------------------

# Globals
use vars qw( $CAPTURE_STARTED $CACHE_KEY $ROOT_DIR $TIME_TO_LIVE $MODE
             $CACHE $CAPTURED_OUTPUT $DEFAULT_CACHE_KEY $CACHE_PATH 
             $WROTE_TO_STDERR $OLD_STDOUT_TIE $OLD_STDERR_TIE );

# 1 indicates that STDOUT is being captured
$CAPTURE_STARTED = 0;

# The cache key
$CACHE_KEY = undef;

# The directory in which the cache resides
$ROOT_DIR = undef;

# The default amount of time the cache entry is to live
$TIME_TO_LIVE = undef;

# The default mode for cache entries
$MODE = undef;

# The cache
$CACHE = undef;

# The temporarily stored STDOUT
$CAPTURED_OUTPUT = '';

# The default cache key. (Actually concatenated with location of temp
# dir.)
$DEFAULT_CACHE_KEY = 'CGI_Cache';

# The default cache key. (Actually concatenated with location of temp
# dir.)
$CACHE_PATH = '';

# Used to determine if there was an error in the script that caused it to
# write to STDERR
$WROTE_TO_STDERR = 0;

# Used to store the old tie'd variables, if any. (Under mod_perl,
# STDOUT is tie'd to the Apache module.) Undef means that there is no
# old tie.
$OLD_STDOUT_TIE = undef;
$OLD_STDERR_TIE = undef;

# --------------------------------------------------------------------------

# This end block ensures that the captured STDOUT will be written to a
# file if the CGI script exits before calling stop(). However, stop()
# will not automatically be called if the script is exiting via a die
# (detected by $? == 2).

END
{
  return unless $CAPTURE_STARTED;

  # Unfortunately, die() writes to STDERR in a magical way that doesn't allow
  # us to catch it. In this case we check $? for an error code.
  if ($WROTE_TO_STDERR || $? == 2)
  {
    stop(0);
  }
  else
  {
    stop(1);
  }
}

# --------------------------------------------------------------------------

# Initialize the cache

sub setup
{
  my $options = shift;

  $options = _set_defaults($options);

  $CACHE = new File::Cache($options);

  die "File::Cache::new failed\n" unless defined $CACHE;

  return 1;
}

# --------------------------------------------------------------------------

sub _set_defaults
{
  my $options = shift;

  # Set default value for namespace
  unless (defined $options->{namespace})
  {
    # Script name may not be defined if we are running in off-line mode
    if (defined $ENV{SCRIPT_NAME})
    {
      (undef,undef,$options->{namespace}) =
        File::Spec->splitpath($ENV{SCRIPT_NAME},0);
    }
    else
    {
      (undef,undef,$options->{namespace}) =
        File::Spec->splitpath($0,0);
    }
  }

  # Set default value for expires_in
  $options->{expires_in} = 24 * 60 * 60
    unless defined $options->{expires_in};


  # Set default value for cache key
  unless (defined $options->{cache_key})
  {
    my $tmpdir = tmpdir() or
      die("No tmpdir on this system.  Bugs to the authors of File::Spec");

    $CACHE_PATH = File::Spec->catfile($tmpdir, $DEFAULT_CACHE_KEY);

    $options->{cache_key} = $CACHE_PATH;
  }


  # Set default value for username
  $options->{username} = "" unless defined $options->{username};

  # Set default value for max_size
  $options->{max_size} = $File::Cache::sNO_MAX_SIZE;

  return $options;
}

# --------------------------------------------------------------------------

sub set_key
{
  my $key = \@_;

  $Storable::canonical = 'true';

  $CACHE_KEY = freeze $key;

  return 1;
}

# --------------------------------------------------------------------------

sub start
{
  # First see if a cached file already exists
  my $cached_output = $CACHE->get($CACHE_KEY);

  if (defined $cached_output)
  {
    print $cached_output;
    exit 0;
  }
  else
  {
    # Store old tie's, if any
    $OLD_STDOUT_TIE = tied *STDOUT;
    $OLD_STDERR_TIE = tied *STDERR;

    # Copy STDOUT to a variable for caching later.
    tie (*STDOUT,'CGI::Cache::CatchSTDOUT');

    # Monitor STDERR to see if the script has any problems
    tie (*STDERR,'CGI::Cache::MonitorSTDERR');

    $CAPTURE_STARTED = 1;
  }

  1;
}

# --------------------------------------------------------------------------

sub stop
{
  return 0 unless ($CAPTURE_STARTED);

  my $cache_output = shift;

  # See if we need to cache the results
  $cache_output = 1 unless defined $cache_output;

  # Stop storing output and restore STDOUT
  untie *STDOUT;
  untie *STDERR;

  tie (*STDOUT,ref $OLD_STDOUT_TIE) if defined $OLD_STDOUT_TIE;
  tie (*STDERR,ref $OLD_STDERR_TIE) if defined $OLD_STDERR_TIE;

  $CAPTURE_STARTED = 0;

  # Cache the saved STDOUT if necessary
  $CACHE->set($CACHE_KEY,$CAPTURED_OUTPUT) if $cache_output;

  # May be important for mod_perl situations
  $CAPTURED_OUTPUT = '';
  $WROTE_TO_STDERR = 0;

  1;
}

# --------------------------------------------------------------------------

package CGI::Cache::CatchSTDOUT;

# These functions are for tie'ing the STDOUT filehandle

sub TIEHANDLE
{
  my $package = shift;

  return bless {},$package;
}

sub WRITE
{
  my($r, $buff, $length, $offset) = @_;

  my $send = substr($buff, $offset, $length);
  print $send;
}

sub PRINT
{
  my $r = shift;

  # Temporarily disable warnings so that we don't get "untie attempted
  # while 1 inner references still exist". Not sure what's the "right
  # thing" to do here.
  local $^W = 0;

  # Temporarily untie the filehandle so that we won't recursively call
  # ourselves
  untie *STDOUT;

  tie (*STDOUT,ref $CGI::Cache::OLD_STDOUT_TIE)
    if defined $CGI::Cache::OLD_STDOUT_TIE;
  $CGI::Cache::CAPTURED_OUTPUT .= join '', @_;
  print @_;
  tie *STDOUT,__PACKAGE__;
}

sub PRINTF
{
  my $r = shift;
  my $fmt = shift;

  print sprintf($fmt, @_);
}

1;

# --------------------------------------------------------------------------

package CGI::Cache::MonitorSTDERR;

# These functions are for tie'ing the STDERR filehandle

sub TIEHANDLE
{
  my $package = shift;

  return bless {},$package;
}

sub WRITE
{
  my($r, $buff, $length, $offset) = @_;

  my $send = substr($buff, $offset, $length);
  print $send;
}

sub PRINT
{
  my $r = shift;

  # Temporarily untie the filehandle so that we won't recursively call
  # ourselves
  untie *STDERR;
  tie (*STDERR,ref $CGI::Cache::OLD_STDERR_TIE)
    if defined $CGI::Cache::OLD_STDERR_TIE;
  print STDERR @_;
  tie *STDERR,__PACKAGE__;

  $CGI::Cache::WROTE_TO_STDERR = 1;
}

sub PRINTF
{
  my $r = shift;
  my $fmt = shift;

  print sprintf($fmt, @_);
}

1;

# --------------------------------------------------------------------------

package CGI::Cache;

1;

__END__

# --------------------------------------------------------------------------

=head1 NAME

CGI::Cache - Perl extension to help cache output of time-intensive CGI
scripts so that subsequent visits to such scripts will not cost as
much time.

=head1 WARNING

The interface as of version 1.01 has changed considerably and is NOT
compatible with earlier versions.

=head1 SYNOPSIS

  use CGI;
  use CGI::Cache;

  my $query = new CGI;

  # Set up a cache in /tmp/CGI_Cache/demo_cgi, with publicly
  # read/writable cache entries, a maximum size of 20 megabytes,
  # and a time-to-live of 6 hours.
  CGI::Cache::setup( { cache_key => '/tmp/CGI_Cache',
                       namespace => 'demo_cgi',
                       filemode => 0666,
                       max_size => 20 * 1024 * 1024,
                       expires_in => 6 * 60 * 60,
                     } );

  # CGI::Vars requires CGI version 2.50 or better
  CGI::Cache::set_key($query->Vars);
  CGI::Cache::start();

  print "Content-type: text/html\n\n";

  print <<EOF;
  <html><body>
  This prints to STDOUT, which will be cached.
  If the next visit is within 6 hours, the cached STDOUT
  will be served instead of executing these 'prints'.
  </body></html>
  EOF


=head1 DESCRIPTION

This module is intended to be used in a CGI script that may
benefit from caching its output. Some CGI scripts may take
longer to execute because the data needed in order to construct
the page may not be readily available. Such a script may need to
query a remote database, or may rely on data that doesn't arrive
in a timely fashion, or it may just be computationally intensive.
Nonetheless, if you can afford the tradeoff of showing older,
cached data vs. CGI execution time, then this module will perform
that function.

This module was written such that any existing CGI code could benefit
from caching without really changing any of existing CGI code guts.
The CGI script can do just what it has always done, that is, construct
an html page and print it to the STDOUT file descriptor, then exit.
What you'll do in order to cache pages is include the module, specify
some cache options and the cache key, and then call start() to begin
caching output.

Internally, the CGI::Cache module ties the STDOUT file descriptor to
an internal variable to which all output to STDOUT is saved. When the
user calls stop() (or the END{} block of CGI::Cache is executed during
script shutdown) the contents of the variable are inserted into the
cache using the cache key the user specified earlier with set_key().

Once a page has been cached in this fashion, then a subsequent visit
to that CGI script will check for an existing cache entry for the
given key before continuing through the code. If the file exists, then
the cache file's content is printed to the real STDOUT and the process
exits before executing the regular CGI code.

=head2 CHOOSING A CACHE KEY

The cache key is used by CGI::Cache to determine when cached
output can be used. The key should be a unique data structure
that fully describes the execution of the script. Conveniently,
CGI::Cache can take the CGI module's parameters (using
CGI::Vars) as the key. However, in some cases you may want to
specially construct the key.

For example, say we have a CGI script "airport" that computes the
number of miles between major airports. You supply two airport codes
to the script and it builds a web pages that reports the number of
miles by air between those two locations. In addition, there is a
third parameter which tells the script whether to write debugging
information to a log file. Suppose the URL for Indianapolis Int'l to
Chicago O'Hare looked like:

  http://www.some.machine/cgi/airport?from=IND&to=ORD&debug=1

We might want to remove the debug parameter because the output from
the user's perspective is the same regardless of whether a log file is
written:

  my $params = $query->Vars;
  delete $params->{'debug'};
  CGI::Cache::set_key($params);
  CGI::Cache::start();

=head2 THE CGI::CACHE ROUTINES

=over 4

=item setup( \%options );

Sets up the cache. The parameters are the same as the parameters for
the File::Cache module's new() method, with the same defaults. Below
is a brief overview of the options and their defaults. This overview
may be out of date with your version of File::Cache. Consult I<perldoc
File::Cache> for more accurate information.

=over 4

=item $options{cache_key}

The cache_key is the location of the cache. Here cache_key is used in keeping
with the terminology used by File::Cache, and is different from the key
referred to in set_key below.

=item $options{namespace}

Namespaces provide isolation between cache objects. It is recommended
that you use a namespace that is unique to your script. That way you
can have multiple scripts whose output is cached by CGI::Cache, and
they will not collide. This value defaults to a subdirectory of your
temp directory whose name matches the name of your script (as reported
by $ENV{SCRIPT_NAME}, or $0 if $ENV{SCRIPT_NAME} is not defined).

=item $options{expires_in}

If the "expires_in" option is set, all objects in this cache will be
cleared after that number of seconds. If expires_in is not set, the
web pages will never expire. The default is 24 hours.

=item $options{cache_key}

The "cache_key" is used to determine the underlying filesystem
namespace to use. Leaving this unset will cause the cache to be
created in a subdirectory of your temporary directory called
CGI_Cache. (The term "key" here is a bit misleading in light of the
usage of the term earlier--this is really the path to the cache.)

=item $options{max_size}

"max_size" specifies the maximum size of the cache, in bytes.  Cache
objects are removed during the set() operation in order to reduce the
cache size before the new cache value is added. The max_size will be
maintained regardless of the value of auto_remove_stale. The default
size is unlimited.

=back


=item set_key ( <data> );

set_key takes any type of data (e.g. a list, a string, a reference to
a complex data structure, etc.) and uses it to create a unique key to
use when caching the script's output.


=item start();

Could you guess that the start() routine is what does all the work? It
is this call that actually looks for an existing cache file, returning
its content if it exists, then exits. If the cache file does not exist,
then it captures the STDOUT filehandle and allows the CGI script's normal
STDOUT be redirected to the cache file.

=item stop( [<cache_output> = 1] );
    <cache_output> - do we write the captured STDOUT to a  cache file?

The stop() routine tells us to stop capturing STDOUT.  The argument
"cache_output" tells us whether or not to store the captured output in
the cache. By default this argument is 1, since this is usually what
we want to do. In an error condition, however, we may not want to
cache the output.  A cache_output argument of 0 is used in this case.

You don't have to call the stop() routine if you simply want to catch
all STDOUT that the script generates for the duration of its
execution.  If the script exits without calling stop(), then the END{}
block of the module will check to see of stop() has been called, and
if not, it will call it. Note that CGI::Cache will detect whether your
script is exiting as the result of an error, and will B<not> cache
the output in this case.

=back

=head1 BUGS

Contact david@coppit.org for bug reports and suggestions.

=head1 AUTHOR

The original code (written before October 1, 2000) was written by Broc
Seib, and is copyright (c) 1998 Broc Seib. All rights reserved. 

Maintenance of CGI::Cache is now being done by David Coppit
(david@coppit.org).

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

 File::Cache
 perldoc -f open

=cut
