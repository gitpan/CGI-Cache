package CGI::Cache;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $DEBUG);

require Exporter;

@ISA = qw(Exporter AutoLoader);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(
	
);
$VERSION = '0.01';


# Preloaded methods go here.
sub Serve ($\%\%) {
  my ($class,$cgi_cache,$file_cache_args)=@_;

  use Data::Dumper;

  warn Data::Dumper->Dump([$cgi_cache,$file_cache_args],['cgi_cache','file_cache_args']);

  use CGI;
  use File::Cache;
  my $cgi=new CGI;
  
  my $cache = new File::Cache ($file_cache_args);
  
  warn $cgi_cache->{key};
  my $pregen_html = $cache->get($cgi_cache->{key});
  
  if ($pregen_html) {
    print $cgi->header, $cgi->start_html, $pregen_html, $cgi->end_html;
    warn "PRINTING pre-gen HTML" if $DEBUG;
    exit;
  } else {
    use LWP::UserAgent;
    use HTTP::Request::Common qw(POST GET);
    my $ua = new LWP::UserAgent;
    my $req = POST $cgi_cache->{url}, { %{$cgi_cache->{fdat}}, 'force_gen' => 1 };
    my $res = $ua->request($req);
    if ($res->is_success()) {
      warn "POST was successful." if $DEBUG;
      my $generated_html = $res->content();
      $cache->set($cgi_cache->{key}, $generated_html);
      print $cgi->header, $cgi->start_html, $generated_html, $cgi->end_html;
      exit;
    } else {
      my $request_string = $req->as_string;
      my $vardump=Data::Dumper->Dump([$cgi_cache,$file_cache_args],['cgi_cache','file_cache_args']);
      my $error_msg = $res->as_string;
      my $date = `date`; chomp($date);
      my $error = "

<h1>Error ($date)</h1>
There was no cached page for $vardump posting as <i>$request_string</i>
<P>
Also, we could not dynamically generate a page. Here is the error:
<b>$error_msg</b>
";
      
      if ($cgi_cache->{display_error}) {
	print $cgi->header, $cgi->start_html, $error, $cgi->end_html;
      } else {
	open T, ">/tmp/cgi-cache-error.html";
	print T $cgi->header, $cgi->start_html, $error, $cgi->end_html;
	close(T);
	print $cgi->redirect($ENV{HTTP_REFERER});
      }
      exit;
    }
  }
}


# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

CGI::Cache - facility for caching the results of CGI scripts

=head1 SYNOPSIS

 # unless the query string to this CGI script explicitly says
 # do not look for pre-generated HTML, lets try to find pregen HTML
 unless ($cgi->param('force_gen')) { 
 # unless ($formdata{force_gen}) { 

  # --------------------------------------------------
  # Caching and Serving of Pre-processed results
  # --------------------------------------------------

  use CGI::Cache;
  CGI::Cache->Serve
    (
     {
      'url'         => 'http://www.angryman.com/cgi-bin/vote/votesearcher.cgi',
      'key'         => $formdata{issueid},
      'display_error'=> 0,
      'fdat'        => \%formdata
     },
     {
      'namespace'  => 'votesearcher.cgi', 
      'expires_in' => 60*10  # 10 minutes till next re-gen
     }
    );
  
  # CGI::Cache->Serve() exits the CGI script here

 }

 # ... the rest of the script is here... and will only run when
 # the query string has explicitly required forced HTML generation.

=head1 DESCRIPTION

CGI::Cache caches the results of cgi scripts so that whatever
time-intensive actions they are engaging in (usually database access)
can be reduced. The first call to the script with CGI::Cache functionality is 
just as slow as the script normally is. The only difference is that the
results of this execution are automatically stored away in a file cache so
that the next call to the script I<with the same key> within the file cache
expiry time will serve the page that was generated the last time.  

F<eg/votesearcher.cgi> shows an example of adding caching facility to a
normally slow cgi script.

The only function of CGI::Cache, Serve(), takes two hash references as
its arguments. The first hashref configures CGI::Cache and the second
argument is passed untouched to File::Cache. The first hashref can take four
arguments, three of which are required:

=over 4

=item * url - the URL of the CGI script you want cached results for. 

=item * fdat - the form data to post to the CGI script

=item * key - a unique key on which to cache this invocation of the
CGI script. It will usually be a value posted to the CGI script. 
For example, if you have a script which is outputting a person's schedule, then
you might key the CGI caching on the person's username, since this will be 
unique.

=item * display_error (OPTIONAL) - tells CGI::Cache what to do in the
event of that the attempt to serve a page (cached or not) is
unsuccessful. If 0, then an error message is written to
/tmp/cgi-cache-error.html and the browser is redirected to the
C<$ENV{HTTP_REFERER}>.  However if C<display_error> is set to a true
value, then the error message will be served to the browser. 

=back

=head1 AUTHOR

T.M. Brannon <TBONE@cpan.org>

=head1 SEE ALSO

=over 4

=item * File::Cache (CPAN id: DCLINTON)

=back

=cut
