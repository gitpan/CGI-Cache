package CGI::Cache;

use strict;
use vars qw( $VERSION );

use File::Path;
use File::Spec;
use File::Spec::Functions qw( tmpdir );
use Cache::SizeAwareFileCache;
use Storable qw( freeze );

$VERSION = '1.20';

# --------------------------------------------------------------------------

# Global because CatchSTDOUT and CatchSTDERR need them
use vars qw( $THE_CAPTURED_OUTPUT $OUTPUT_HANDLE $ERROR_HANDLE 
             $WROTE_TO_STDERR );

# Global because test script needs them. They really should be lexically
# scoped to this package.
use vars qw( $THE_CACHE $THE_CACHE_KEY $CACHE_PATH );

my $DEFAULT_EXPIRES_IN = 24 * 60 * 60;

# 1 indicates that we started capturing output
my $CAPTURE_STARTED = 0;

# 1 indicates that we are currently capturing output
my $CAPTURING = 0;

# The cache key
$THE_CACHE_KEY = undef;

# The cache
$THE_CACHE = undef;

# Path to cache. Used by test harness to clean things up.
$CACHE_PATH;

# The temporarily stored output
$THE_CAPTURED_OUTPUT = '';

# Used to determine if there was an error in the script that caused it to
# write to STDERR
$WROTE_TO_STDERR = 0;
my $CALLED_WARN_OR_DIE = 0;

# The filehandles to monitor. These are normally STDOUT and STDERR.
my $WATCHED_OUTPUT_HANDLE = undef;
my $WATCHED_ERROR_HANDLE = undef;

# References to the filehandles to send output to. These are normally STDOUT
# and STDERR.
$OUTPUT_HANDLE = undef;
$ERROR_HANDLE = undef;

# Used to store the old tie'd variables, if any. (Under mod_perl,
# STDOUT is tie'd to the Apache module.) Undef means that there is no
# old tie.
my $OLD_STDOUT_TIE = undef;
my $OLD_STDERR_TIE = undef;

# The original warn and die handlers
my $OLD_WARN = undef;
my $OLD_DIE = undef;

# --------------------------------------------------------------------------

sub CGI_Cache_warn
{
  $CALLED_WARN_OR_DIE = 1;

  if ( defined $OLD_WARN )
  {
    &$OLD_WARN( @_ );
  }
  else
  {
    CORE::warn( @_ );
  }
}

# --------------------------------------------------------------------------

sub CGI_Cache_die
{
  $CALLED_WARN_OR_DIE = 1;

  if ( defined $OLD_DIE )
  {
    &$OLD_DIE( @_ );
  }
  else
  {
    CORE::die( @_ );
  }
}

# --------------------------------------------------------------------------

# This end block ensures that the captured output will be written to a
# file if the CGI script exits before calling stop(). However, stop()
# will not automatically be called if the script is exiting via a die

END
{
  return unless $CAPTURE_STARTED;

  # Unfortunately, die() writes to STDERR in a magical way that doesn't allow
  # us to catch it. In this case we check $? for an error code.
  if ( $CALLED_WARN_OR_DIE || $WROTE_TO_STDERR || $? == 2 )
  {
    stop( 0 );
  }
  else
  {
    stop( 1 );
  }
}

# --------------------------------------------------------------------------

# Initialize the cache

sub setup
{
  my $options = shift;

  $options = {} unless defined $options;

  die "CGI::Cache::setup() takes a single hash reference for options"
    unless UNIVERSAL::isa($options, 'HASH') && !@_;

  $options = _set_defaults( $options );

  $THE_CACHE = new Cache::SizeAwareFileCache( $options->{cache_options} );
  die "Cache::SizeAwareFileCache::new failed\n" unless defined $THE_CACHE;

  $WATCHED_OUTPUT_HANDLE = $options->{watched_output_handle};
  $WATCHED_ERROR_HANDLE = $options->{watched_error_handle};

  $OUTPUT_HANDLE = $options->{output_handle};
  $ERROR_HANDLE = $options->{error_handle};

  return 1;
}

# --------------------------------------------------------------------------

sub _set_defaults
{
  my $options = shift;

  $options->{cache_options} =
    _set_cache_defaults( $options->{cache_options} );

  $options->{watched_output_handle} = \*STDOUT
    unless defined $options->{watched_output_handle};

  $options->{watched_error_handle} = \*STDERR
    unless defined $options->{watched_error_handle};

  $options->{output_handle} = $options->{watched_output_handle}
    unless defined $options->{output_handle};

  $options->{error_handle} = $options->{watched_error_handle}
    unless defined $options->{error_handle};

  return $options;
}

# --------------------------------------------------------------------------

sub _set_cache_defaults
{
  my $cache_options = shift;

  # Set default value for namespace
  unless ( defined $cache_options->{namespace} )
  {
    # Script name may not be defined if we are running in off-line mode
    if ( defined $ENV{SCRIPT_NAME} )
    {
      ( undef, undef, $cache_options->{namespace} ) =
        File::Spec->splitpath( $ENV{SCRIPT_NAME}, 0 );
    }
    else
    {
      ( undef, undef, $cache_options->{namespace} ) =
        File::Spec->splitpath( $0, 0 );
    }
  }

  # Set default value for expires_in
  $cache_options->{expires_in} = $DEFAULT_EXPIRES_IN
    unless defined $cache_options->{default_expires_in};


  # Set default value for cache root
  $cache_options->{cache_root} = _compute_default_cache_root()
    unless defined $cache_options->{cache_root};

  # Set default value for max_size
  $cache_options->{max_size} = $Cache::SizeAwareFileCache::NO_MAX_SIZE;

  return $cache_options;
}

# --------------------------------------------------------------------------

sub _compute_default_cache_root
{
  my $tmpdir = tmpdir() or
    die( "No tmpdir() on this system. " .
         "Send a bug report to the authors of File::Spec" );

  $CACHE_PATH = File::Spec->catfile( $tmpdir, 'CGI_Cache' );

  return $CACHE_PATH;
}

# --------------------------------------------------------------------------

sub set_key
{
  my $key = \@_;

  $Storable::canonical = 'true';

  $THE_CACHE_KEY = freeze $key;

  return 1;
}

# --------------------------------------------------------------------------

sub start
{
  die "Cache key must be defined before calling CGI::Cache::start()"
    unless defined $THE_CACHE_KEY;

  # First see if a cached file already exists
  my $cached_output = $THE_CACHE->get( $THE_CACHE_KEY );

  if ( defined $cached_output )
  {
    print $OUTPUT_HANDLE $cached_output;
    return 0;
  }
  else
  {
    _bind();

    $CAPTURE_STARTED = 1;

    return 1;
  }
}

# --------------------------------------------------------------------------

sub stop
{
  return 0 unless $CAPTURE_STARTED;

  my $cache_output = shift;
  $cache_output = 1 unless defined $cache_output;

  _unbind();

  # Cache the saved output if necessary
  $THE_CACHE->set( $THE_CACHE_KEY, $THE_CAPTURED_OUTPUT ) if $cache_output;

  # May be important for mod_perl situations
  $CAPTURE_STARTED = 0;
  $THE_CAPTURED_OUTPUT = '';
  $WROTE_TO_STDERR = 0;
  $CALLED_WARN_OR_DIE = 0;
  $THE_CACHE_KEY = undef;

  return 1;
}

# --------------------------------------------------------------------------

sub pause
{
  # Nothing happens if capturing was not started, or you are not currently
  # capturing
  return 0 unless $CAPTURE_STARTED && $CAPTURING;

  _unbind( 'output' );

  return 1;
}

# --------------------------------------------------------------------------

sub continue
{
  # Nothing happens unless capturing was started and you are currently
  # not capturing
  return 0 unless $CAPTURE_STARTED && !$CAPTURING;

  _bind( 'output' );

  return 1;
}

# --------------------------------------------------------------------------

sub _bind
{
  my @handles = @_;

  @handles = ( 'output', 'error' ) unless @handles;

  if (grep /output/, @handles)
  {
    $OLD_STDOUT_TIE = tied $$WATCHED_OUTPUT_HANDLE;

    # Tie the output handle to monitor output
    tie ( $$WATCHED_OUTPUT_HANDLE, 'CGI::Cache::CatchSTDOUT' );

    $CAPTURING = 1;
  }

  if (grep /error/, @handles)
  {
    $OLD_STDERR_TIE = tied $$WATCHED_ERROR_HANDLE;

    # Monitor STDERR to see if the script has any problems
    tie ( $$WATCHED_ERROR_HANDLE, 'CGI::Cache::MonitorSTDERR' );

    # Store the previous warn() and die() handlers, unless they are ours. (We
    # don't want to call ourselves if the user calls setup twice!)
    if ( $main::SIG{__WARN__} ne \&CGI_Cache_warn )
    {
      $OLD_WARN = $main::SIG{__WARN__} if $main::SIG{__WARN__} ne '';
      $main::SIG{__WARN__} = \&CGI_Cache_warn;
    }

    if ( $main::SIG{__DIE__} ne \&CGI_Cache_die )
    {
      $OLD_DIE = $main::SIG{__DIE__} if $main::SIG{__DIE__} ne '';
      $main::SIG{__DIE__} = \&CGI_Cache_die;
    }
  }
}

# --------------------------------------------------------------------------

sub _unbind
{
  my @handles = @_;

  @handles = ( 'output', 'error' ) unless @handles;

  if (grep /output/, @handles)
  {
    untie $$WATCHED_OUTPUT_HANDLE;

    if (defined $OLD_STDOUT_TIE)
    {
      tie ( $$WATCHED_OUTPUT_HANDLE, "CGI::Cache::RestoreTie",
        $OLD_STDOUT_TIE );
      undef $OLD_STDOUT_TIE;
    }

    $CAPTURING = 0;
  }

  if (grep /error/, @handles)
  {
    untie $$WATCHED_ERROR_HANDLE;

    if (defined $OLD_STDERR_TIE)
    {
      tie ( $$WATCHED_ERROR_HANDLE, "CGI::Cache::RestoreTie",
        $OLD_STDERR_TIE );
      undef $OLD_STDERR_TIE;
    }

    $main::SIG{__DIE__} = $OLD_DIE;
    undef $OLD_DIE;
    $main::SIG{__WARN__} = $OLD_WARN; 
    undef $OLD_WARN;
  }
}

# --------------------------------------------------------------------------

sub invalidate_cache_entry
{
  $THE_CACHE->remove( $THE_CACHE_KEY );

  return 1;
}

# --------------------------------------------------------------------------

sub buffer
{
  $THE_CAPTURED_OUTPUT = join( '', @_ ) if @_;

  return $THE_CAPTURED_OUTPUT;
}

1;

# ##########################################################################

package CGI::Cache::RestoreTie;

(*TIESCALAR, *TIEARRAY, *TIEHASH, *TIEHANDLE) =
  ( sub { $_[1] } ) x 4;

1;

############################################################################

package CGI::Cache::CatchSTDOUT;

# These functions are for tie'ing the output filehandle

sub TIEHANDLE
{
  my $package = shift;

  return bless {}, $package;
}

sub WRITE
{
  my( $r, $buff, $length, $offset ) = @_;

  my $send = substr( $buff, $offset, $length );
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
  CGI::Cache::_unbind( 'output' );

  $CGI::Cache::THE_CAPTURED_OUTPUT .= join '', @_;

  print $CGI::Cache::OUTPUT_HANDLE @_;

  CGI::Cache::_bind( 'output' );
}

sub PRINTF
{
  my $r = shift;
  my $fmt = shift;

  print sprintf( $fmt, @_ );
}

1;

############################################################################

package CGI::Cache::MonitorSTDERR;

# These functions are for tie'ing the STDERR filehandle

sub TIEHANDLE
{
  my $package = shift;

  return bless {}, $package;
}

sub WRITE
{
  my( $r, $buff, $length, $offset ) = @_;

  my $send = substr( $buff, $offset, $length );
  print $send;
}

sub PRINT
{
  my $r = shift;

  # Temporarily untie the filehandle so that we won't recursively call
  # ourselves
  CGI::Cache::_unbind( 'error' );

  print $CGI::Cache::ERROR_HANDLE @_;

  $CGI::Cache::WROTE_TO_STDERR = 1;

  CGI::Cache::_bind( 'error' );
}

sub PRINTF
{
  my $r = shift;
  my $fmt = shift;

  print sprintf( $fmt, @_ );
}

1;

__END__

# --------------------------------------------------------------------------

=head1 NAME

CGI::Cache - Perl extension to help cache output of time-intensive CGI
scripts so that subsequent visits to such scripts will not cost as
much time.

=head1 WARNING

The interface as of version 1.01 has changed considerably and is NOT
compatible with earlier versions. A smaller interface change also occurred in
version 1.20.

=head1 SYNOPSIS

  use CGI;
  use CGI::Cache;

  my $query = new CGI;

  # Set up a cache in /tmp/CGI_Cache/demo_cgi, with publicly
  # unreadable cache entries, a maximum size of 20 megabytes,
  # and a time-to-live of 6 hours.
  CGI::Cache::setup( { cache_root => '/tmp/CGI_Cache',
                       namespace => 'demo_cgi',
                       directory_umask => 077,
                       max_size => 20 * 1024 * 1024,
                       default_expires_in => '6 hours',
                     } );

  # CGI::Vars requires CGI version 2.50 or better
  CGI::Cache::set_key( $query->Vars );
  CGI::Cache::invalidate_cache_entry()
    if $query->param( 'force_regenerate' ) eq 'true';
  CGI::Cache::start() or exit;

  print "Content-type: text/html\n\n";

  print <<EOF;
  <html><body>
  <p>
  This prints to STDOUT, which will be cached.
  If the next visit is within 6 hours, the cached STDOUT
  will be served instead of executing these 'prints'.
  </p>
  EOF

  CGI::Cache::pause();

  print <<EOF;
  <p>This is not cached.</p>
  EOF

  CGI::Cache::continue();

  print <<EOF;
  </body></html>
  EOF

  # Optional unless you're using mod_perl for FastCGI
  CGI::Cache::stop();

=head1 DESCRIPTION

This module is intended to be used in a CGI script that may
benefit from caching its output. Some CGI scripts may take
longer to execute because the data needed in order to construct
the page may not be quickly computed. Such a script may need to
query a remote database, or may rely on data that doesn't arrive
in a timely fashion, or it may just be computationally intensive.
Nonetheless, if you can afford the tradeoff of showing older,
cached data vs. CGI execution time, then this module will perform
that function.

This module was written such that any existing CGI code could benefit
from caching without really changing any of existing CGI code guts.
The CGI script can do just what it has always done, that is, construct
an html page and print it to the output file descriptor, then exit.
What you'll do in order to cache pages is include the module, specify
some cache options and the cache key, and then call start() to begin
caching output.

Internally, the CGI::Cache module ties the output file descriptor (usually
STDOUT) to an internal variable to which all output is saved. When the user
calls stop() (or the END{} block of CGI::Cache is executed during script
shutdown) the contents of the variable are inserted into the cache using the
cache key the user specified earlier with set_key().

Once a page has been cached in this fashion, a subsequent visit to that page
will invoke the start() function again, which will then check for an existing
cache entry for the given key before continuing through the code. If the cache
entry exists, then the cache entry's content is printed to the output
filehandle (usually STDOUT) and a 0 is returned to indicate that cached output
was used.

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
  CGI::Cache::set_key( $params );
  CGI::Cache::start() or exit;

=head2 THE CGI::CACHE ROUTINES

=over 4

=item setup( { cache_options => \%cache_options,
               [watched_output_handle => \*STDOUT],
               [watched_error_handle => \*STDERR] );
               [output_handle => <watched_output_handle>],
               [error_handle => <watched_error_handle>] } );

    <cache_options> - options for configuration of the cache
    <watched_output_handle> - the file handle to monitor for normal output
    <watched_error_handle> - the file handle to monitor for error output
    <output_handle> - the file handle to which to send normal output
    <error_handle> - the file handle to which to send error output

Sets up the cache. The I<cache_options> parameter contains the same values as
the parameters for the Cache::SizeAwareFileCache module's new() method, with
the same defaults. Below is a brief overview of the options and their
defaults. This overview may be out of date with your version of
Cache::SizeAwareFileCache. Consult I<perldoc Cache::SizeAwareFileCache> for
more accurate information.

=over 4

=item $cache_options{cache_root}

The cache_root is the file system location of the cache.  Leaving this unset
will cause the cache to be created in a subdirectory of your temporary
directory called CGI_Cache.

=item $cache_options{namespace}

Namespaces provide isolation between cache objects. It is recommended
that you use a namespace that is unique to your script. That way you
can have multiple scripts whose output is cached by CGI::Cache, and
they will not collide. This value defaults to a subdirectory of your
temp directory whose name matches the name of your script (as reported
by $ENV{SCRIPT_NAME}, or $0 if $ENV{SCRIPT_NAME} is not defined).

=item $cache_options{default_expires_in}

If the "default_expires_in" option is set, all objects in this cache will be
cleared after that number of seconds. If expires_in is not set, the web pages
will never expire. The default is 24 hours.

=item $cache_options{max_size}

"max_size" specifies the maximum size of the cache, in bytes.  Cache objects
are removed during the set() operation in order to reduce the cache size
before the new cache value is added. The default size is unlimited.

=back

Normally CGI::Cache monitors STDOUT and STDERR, capturing output and caching
it if there are no errors. However, with the remaining four optional
parameters, you can modify the filehandles that CGI::Cache listens on and
outputs to. The watched handles are the handles which CGI::Cache will monitor
for output. The output and error handles are the handles to which CGI::Cache
will send the output after it is cached. These default to whatever the
watched handles are. This feature is useful when CGI::Cache is used to
cache output to files:

  use CGI::Cache;

  open FH, ">TEST.OUT";

  CGI::Cache::setup( { watched_output_handle => \*FH } );
  CGI::Cache::set_key( 'test key' );
  CGI::Cache::start() or exit;

  # This is cached, and then sent to FH
  print FH "Test output 1\n";

  CGI::Cache::stop();

  close FH;

NOTE: If you plan to modify warn() or die() (i.e. redefine $SIG{__WARN__} or
$SIG{__DIE__}) so that they no longer print to STDERR, you must do so before
calling setup(). For example, if you do a "require CGI::Carp
qw(fatalsToBrowser)", make sure you do it before calling CGI::Cache::setup().


=item set_key ( <data> );

set_key takes any type of data (e.g. a list, a string, a reference to
a complex data structure, etc.) and uses it to create a unique key to
use when caching the script's output.


=item start();

Could you guess that the start() routine is what does all the work? It is this
call that actually looks for an existing cache file and prints the output if
it exists. If the cache file does not exist, then CGI::Cache captures the
output filehandle and redirects the CGI script's output to the cache file.

This function returns 1 if caching has started, and 0 if the cached output was
printed. A common metaphor for using this function is:

  CGI::Cache::start() or exit;

This function dies if you haven't yet defined your cache key.


=item $status = stop( [<cache_output>] );

    <cache_output> - do we write the captured output to a cache file?

The stop() routine tells us to stop capturing output.  The argument
"cache_output" tells us whether or not to store the captured output in
the cache. By default this argument is 1, since this is usually what
we want to do. In an error condition, however, we may not want to
cache the output.  A cache_output argument of 0 is used in this case.

You don't have to call the stop() routine if you simply want to catch
all output that the script generates for the duration of its
execution.  If the script exits without calling stop(), then the END{}
block of the CGI::cache will check to see of stop() has been called,
and if not, it will call it. Note that CGI::Cache will detect whether
your script is exiting as the result of an error, and will B<not>
cache the output in this case.

This function returns 0 if capturing has not been started (by a call
to start()), and 1 otherwise.

=item $status = pause();

Temporarily disable caching of output. Returns 0 if CGI::Cache
is not currently caching output, and 1 otherwise.


=item $status = continue();

Enable caching of output.  This function returns 0 if capturing has
not been started (by a call to start()) or if pause() was not
previously called, and 1 otherwise.


=item $scalar = buffer( [<content>] );

The buffer method gives direct access to the buffer of cached output. The
optional <content> parameter allows you to set the contents using a list or
scalar. (The list will be joined into a scalar and stored in the buffer.) The
return value is the contents of the buffer after any changes.


=item $status = invalidate_cache_entry();

Forces the cache entry to be invalidated. It is always successful, and always
returns 1. It doesn't make much sense to call this after calling start(), as
CGI::Cache will have already determined that the cache entry is invalid.


=head1 BUGS

No known bugs.

Contact david@coppit.org for bug reports and suggestions.

=head1 AUTHOR

The original code (written before October 1, 2000) was written by Broc
Seib, and is copyright (c) 1998 Broc Seib. All rights reserved. 

Maintenance of CGI::Cache is now being done by David Coppit
(david@coppit.org).

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

Cache::SizeAwareFileCache

=cut
