package CGI::Cache;

use strict;
use vars qw($VERSION $G);	# @ISA @EXPORT @EXPORT_OK);

use File::Path;


$VERSION = '0.99';


BEGIN {
	$G = {	## $G is our "global" variables.
		'IS_CAPTURED'	=> 0,
		'CACHE_FILE'	=> undef,
		'ROOT_DIR'		=> undef,
		'TTL'			=> undef,
	};
}

END {
	Stop() if ($G->{'IS_CAPTURED'});
}


sub SetRoot {
	my $root = shift || return 0;
	my $mode = shift;
	return 0 if ($root !~ /^\//);

	##
	#	see about having to build directories
	##
	$mode = 0777 if (!defined($mode));
	if ($mode != 0) {	#  mkpath only if there's non-zero mode!
		unless (-d $root) {
			my $old = umask 0;
			mkpath($root,0,$mode);
			umask $old;
		}
	}

	##
	#	test to see if the path is there now
	##
	return 0 unless (-d $root);

	$G->{'ROOT_DIR'} = $root;
	return 1;
}


sub SetFile {
	my $file = shift || return 0;
	my $ttl = shift;

	return 0 if ($file eq "");

	if ($file =~ /\//) {	# we contain subdirs or abs path
		if (defined($G->{'ROOT_DIR'}) && $file !~ /^\//) {
			$file =  "$G->{'ROOT_DIR'}/$file";
		}
		$file =~ s#//#/#g;	# no double slashes
		my @dirs = split(/\//,$file);
		$file = pop @dirs;
		my $root = join('/',@dirs);
		SetRoot($root) || return 0;
	}
	$G->{'CACHE_FILE'} = $file;

	##
	#	record the time to live value
	##
	$ttl = 12*60*60 if (!defined($ttl));
	$G->{'TTL'} = $ttl;

	1;
}


sub Start {
	if (@_) {	# if there are args, must be meant for SetFile()
		SetFile(@_) || return 0;
	}

	##
	#	see if a cache file already exists
	##
	my $file = _pure_cachefile_name();
	if (-r $file) {
		##
		#	see if cache file is expired. If not,
		#	then dump it and exit
		##
		my $age = 24*60*60*(-M $file);
		if ($age < $G->{'TTL'}) {
			_dump_cachefile();
			exit 0;
		}
	}

	##
	#	OK, we must capture all stdout into a cache file
	##
	my $old = umask 022;
	unless (open REALSTDOUT, ">&STDOUT" ) {
		return 0;
	}
	unless (open STDOUT, ">$file") {
		umask $old;
		open STDOUT, ">&REALSTDOUT"; # restore real STDOUT - can't open cache
		return 0;
	}
	$G->{'IS_CAPTURED'} = 1;
	umask $old;
	1;
}


sub Stop {
	return 0 unless ($G->{'IS_CAPTURED'});

	##
	#	get flag for dumping or no dumping
	##
	my $dump = shift;
	$dump = 1 if (!defined($dump));

	##
	#	restore stdout
	##
	close STDOUT;
	open STDOUT, ">&REALSTDOUT";	# restore real stdout
	$G->{'IS_CAPTURED'} = 0;

	##
	#	dump the cachefile or expire it
	##
	if ($dump) {
		_dump_cachefile();
	} else {
		Expire();
	}

	1;
}


sub Expire {
	if (@_) {	# if there are args, must be meant for SetFile()
		SetFile(@_) || return 0;
	}

	my $file = _pure_cachefile_name();
	return unlink $file if (-e $file);
	return 0;	# no such file found
}


sub _dump_cachefile {
	my $file = _pure_cachefile_name();
	if (open(FH,$file)) {
		print <FH>;
		close FH;
	} else {
		##
		#	Is there something better I should do here?
		#	This is a last ditch effort to be sociable to the browser.
		##
		print "Content-type: text/html\n\nError CGI::Cache\n";
	}
}


sub _pure_cachefile_name {
	my $cf = $G->{'CACHE_FILE'};
	if (defined($G->{'ROOT_DIR'})) {
		$cf = "$G->{'ROOT_DIR'}/$cf";
		$cf =~ s#//#/#g;
	}
	return $cf;
}


1;
__END__

=head1 NAME

CGI::Cache - Perl extension to help cache output of time-intensive CGI scripts so that subsequent visits to such scripts will not cost as much time.

=head1 SYNOPSIS

  use CGI::Cache;

  $TTL = 6*60*60;	# time to live for cache file is 6 hours
  CGI::Cache::SetFile('/tmp/cgi_cache/sample_cachefile.html',$TTL);
  CGI::Cache::Start();

  print "Content-type text/html\n\n";
  print "This prints to STDOUT, which will be cached.";
  print "If the next visit is within 6 hours, the cached STDOUT";
  print "will be served instead of executing these 'prints'.";


=head1 INSTALLATION

To install this package, change to the directory where you
unarchived this distribution and type the following:

	perl Makefile.PL
	make
	make test
	make install

During the 'make test', there are some tests that take a while
longer to run. While testing that caching is working, CPU times
are being recorded on some badly written code to see that
performance will actually be increased on subsequent visits.
Don't panic. It may take a couple of minutes to run, depending
on your system.

If you do not have root access on your machine, then you may
not have the ability to install this module in the standard
perl library path. You may direct the installation into your
own space, e.g.,

	perl Makefile.PL LIB='/home/bseib/lib'

or perhaps the entire installation, e.g.,

	perl Makefile.PL PREFIX='/home/bseib'

If you make the installation into your own directory, then
remember that you must tell perl where to search for modules
before trying to 'use' them. For example:

	use lib '/home/bseib/lib';
	use CGI::Cache;


The most current version of this module should be available
at your favorite CPAN site, or may be retrieved from
  http://icd.cc.purdue.edu/~bseib/pub/CGI-Cache-0.99.tar.gz

Please let me know if you are using this module. Tell me what
bugs you find or what can be done to improve it.


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

This module was written such that any existing CGI code could
benefit from caching without really changing any of existing CGI
code guts. The idea is that you include the module and concoct
a filename for the cache file.

This module accomplishes that feat by allowing the CGI script to
do just what it has always done, that is, construct an html page
and print it to the STDOUT file descriptor, then exit. What
you'll do in order to cache pages is include the module, specify
a cache filename, and all output on STDOUT will be redirected to
the cache file instead. Upon exit, the content of the cache file
will be blasted onto the real STDOUT.

This functionallity is performed by "duping" the STDOUT file
descriptor and opening the named cache file via the STDOUT file
descriptor. If this is unfamiliar, you should read the section
on the perl open() function in the Camel book, or in perldoc perlfunc.
There is an example of capturing STDOUT this way.

Once a page has been cached in this fashion, then a subsequent
visit to that CGI script will check for the cache file before
continuing through the code. If the file exists, then the
cache file's content is printed to the real STDOUT and the
process exits before executing the regular CGI code.

=head2 CHOOSING A CACHE FILE NAME

You must consider the nature of the CGI script to choose an
appropriate cache file name. Think of your CGI script as a math
function that produces a unique result as a function of one or
more input variables. You want to save that result under a name
that is a combination of all the variables that it took to create
that result.

For example, say we have a CGI script "airport" that computes the
number of miles between major airports. You supply two airport codes
to the script and it builds a web pages that reports the number of
miles by air between those two locations. Suppose the URL for
Indianapolis Int'l to Chicago O'Hare looked like:

	http://www.some.machine/cgi/airport?IND+ORD

We might choose a cache file name like "airport_IND_ORD", or 
"airport.IND.ORD", any name that contains all the variables that
it took to create the page.

So where does this cache file actually get created? There are two
subroutines that can affect where the actual cache file is created.
The first sets up a general "root" directory for all caching. A
second routine tells what filename to use for a specific cache file.

=head2 THE CGI::CACHE ROUTINES

=over 4

=item SetRoot

	SetRoot( <abs_path> [,<mode> = undef] );
	  <abs_path>  - absolute path to a directory for cache files
	  <mode>
	    undef     - attempt to mkpath this path with mode 0777
	    0xxx      - attempt to mkpath this path with mode 0xxx
	    0         - do not attempt to mkpath this path

Calling SetRoot() you setup an absolute path to a directory where
cache files may be created. If the supplied path does not begin
with a '/' character, then it is ignored and a failure code of
0 is returned.

A second optional argument controls whether or not we attempt to
mkpath that path if it doesn't exist entirely.  If we pass a zero
for this second argument and the path doesn't exist, then we won't
attempt to mkpath the path and return a failure code of 0. However,
if the path exists, the routine succeeds, returning 1.

You may pass a non-zero octal mode as the second argument, which
will be the mode set while creating directories when calling mkpath().
During this subroutine, the process's umask will temporarily be set
to 0000. All the directories that are created will then have the
specified mode.

If you leave out the second argument, i.e. it is undef, then a
mkpath is attempted and the default mode of 0777 is used.

=item SetFile

	SetFile( <path> [,<ttl> = 12*60*60] );
	  <path>      - a relative or absolute path to cache file
	  <ttl>       - number of seconds the cache file will live

Calling SetFile() you specify the actual filename that the
cache file will have inside the root cache directory. You may
optionally supply an integer that determines a cache file's
time to live. This indicates the number of seconds a file may
age and still be served. The default time to live, if not
supplied, is 12 hours.

Going back to our simple "airport" CGI example, we could modify
our existing CGI script with a preamble to do the caching. E.g.,

  #!/usr/local/bin/perl -w
  
  ###
  ##   Add these few lines up front to get caching.
  ###
  use CGI::Cache;
  CGI::Cache::SetRoot('/tmp/cgi-cache/');
  CGI::Cache::SetFile("airport_" . join('_', sort @ARGV) );
  CGI::Cache::Start();
  
  ###
  ##   put normal CGI code here
  ###
  
  ###
  ##   EOF
  ###

This is a simplified example of taking the arguments to the CGI
script and joining them with underscores and using that as part
of the unique cache file name. The SetRoot() call will attempt to
mkpath('/tmp/cgi-cache/') with mode 0777. After visiting a few
pages you might have a cache directory that looks like:

  /tmp/cgi-cache/
     airport_IND_ORD
     airport_DFW_IND
     airport_IND_JFK
     airport_JFK_LAX


Note that all your CGI scripts may start piling up cache files in
the same directory. If this is not desired you can specify a subdirectory
back where you called the SetFile() routine, like this:

  CGI::Cache::SetFile("airport/$somefilename");

Now the work of the "airport" CGI script stays separated in its own
directory. This is desirable, for example, if you had another CGI
script showing upcoming flights. In this case, the cache directory
may now look something like:

  /tmp/cgi-cache/airport/
     IND_ORD
     DFW_IND
     IND_JFK
     JFK_LAX
  /tmp/cgi-cache/flights/
     IND_ORD.ATA
     IND_ORD.TWA
     IND_ORD.United
     DFW_IND.ATA
     DFW_IND.TWA
     DFW_IND.Delta
     JFK_LAX.AmericanAirlines
     ...etc...

When supplying paths to SetFile() that have a subdirectory (implied by
the "/" character[s] in the string), then the default mkpath() applies to
making those directories if they do not exist. If you do not want
mkpath() building directories behind your back, then you should be
specifying this up front with SetRoot('/the/dir/you/want/',0).

You may also supply a full path to SetFile() as well. The same mkpath()
rules will apply by default.


=item Start

	Start();

Could you guess that the Start() routine is what does all the work? It
is this call that actually looks for an existing cache file, returning
its content if it exists, then exits. If the cache file does not exist,
then it captures the STDOUT filehandle and allows the CGI script's normal
STDOUT be redirected to the cache file.

This routine can also take the same arguments as SetFile(), in which case
the routine Start() will actually call SetFile() first with those arguments
before it does anything else. E.g.,

	Start( <path> [,<ttl> = 12*60*60] );
	  <path>      - a relative or absolute path to cache file
	  <ttl>       - number of seconds the cache file will live

This allows us to shorten our example preamble to just two lines!

  #!/usr/local/bin/perl -w
  
  ###
  ##   Add these two lines up front to get caching with TTL = 10 min.
  ##   Assume $filename has been set to appropriate cache file name.
  ###
  use CGI::Cache;
  CGI::Cache::Start("/tmp/cgi-cache/airport/$filename", 600);
  
  ###
  ##   put normal CGI code here
  ###
  
  ###
  ##   EOF
  ###


=item Stop

	Stop( [<dump> = 1] );
	  <dump>      - do we dump the the cache file to STDOUT?

The Stop() routine tells us to stop capturing STDOUT to the cache file.
The cache file is closed and the file descriptor for STDOUT is restored
to normal. The argument "dump" tells us whether or not to dump what has
been captured in the cache file to the real STDOUT. By default this
argument is 1, since this is usually what we want to do. In an error
condition, however, we may want to cease caching and not print any of
it to STDOUT. In this case, a dump argument of 0 is passed, which actually
causes Stop() to call Expire() to delete the cache file.

You don't have to call the Stop() routine if you simply want to catch
all STDOUT that the script generates for the duration of its execution.
If the script exits without calling Stop(), then the END { } block of
the module will check to see of Stop() has been called, and if not,
it will call it.

=item Expire

	Expire( );

The Expire() routine lets us explicitly expire a cache file, even if it
has not aged beyond its time to live. This routine simply unlinks the
cache file to delete it. Depending on your CGI script, there may be
an occasion where you will want to do this.

You can also supply a cache file name to this routine to specifically
nuke a particular cache file.

=back

=head1 BUGS

This module works by regurgitating the cache file to real STDOUT upon
normal exit of the process. If the process terminates abnormally, two
things may happen: 1) the cache file may have only part of STDOUT cached
which affects subsequent visits, 2) the cache file may not be regurgitated
upon the abnornal termination of the process.

If your processes are exiting abnormally, you may have bigger problems,
or need some signal handling. I'll take suggestions if there is something
that can be done here.

Contact bseib@purdue.edu for bug reports and suggestions.

=head1 AUTHOR

Copyright (c) 1998 Broc Seib. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms as
Perl itself.

=head1 REVISION

$Id: Cache.pm,v 1.3 1998/06/18 01:00:46 bseib Exp $

=head1 SEE ALSO

 perldoc -f open
 File::Path::mkpath().

=cut
