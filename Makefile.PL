use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

Verify_OK_To_Install() unless grep { /^FORCE_INSTALL$/ } @ARGV;

sub Verify_OK_To_Install
{
  if (eval "require CGI::Cache" && $CGI::Cache::VERSION <= 1.00)
  {
    print <<EOF;
WARNING!

The interface to CGI::Cache has changed substantially in this version. Any
scripts developed using previous versions CGI::Cache will NOT work.

Do you want to continue installing CGI::Cache?
EOF

    my $answer;
    do
    {
      $answer = <STDIN>;
    } until $answer =~ /^[yn]/i;

    exit 1 if $answer =~ /^n/i;
  }
  elsif (eval "require CGI::Cache" && $CGI::Cache::VERSION <= 1.20)
  {
    print <<EOF;
WARNING!

The interface to CGI::Cache has changed slightly in this version. Any
scripts developed using previous versions CGI::Cache will likely not
work.

Do you want to continue installing CGI::Cache?
EOF

    my $answer;
    do
    {
      $answer = <STDIN>;
    } until $answer =~ /^[yn]/i;

    exit 1 if $answer =~ /^n/i;
  }
}


# Have to do this because MakeMaker and POSIX collide because someone used
# @EXPORT when they should have used @EXPORT_OK. See
# http://www.deja.com/=dnt_mn/getdoc.xp?AN=469218990&fmt=text
unless (eval "require POSIX")
{
  print "Warning: prerequisite POSIX 0 not found\n";
}


WriteMakefile(
    'NAME'	=> 'CGI::Cache',
    'VERSION_FROM' => 'Cache.pm', # finds $VERSION
    'PREREQ_PM' => { 'File::Path' => 0,
                     'File::Spec' => 0,
                     'File::Spec::Functions' => 0,
                     'Cache::SizeAwareFileCache' => 0,
                     'Storable' => 0,
                     'IO::File' => 0,
    },
);
