#!/usr/bin/perl
# use perl                                  -*- mode: Perl; -*-

use strict;
use ExtUtils::MakeMaker;

unless ((grep {/^PREFIX=/} @ARGV) || (grep {/^INSTALLDIRS=/} @ARGV))
{
  @ARGV = Set_Install_Options(@ARGV);
}

print "\n","-"x78,"\n\n";

my %makefile_attributes = Compute_Makefile_Attributes();

WriteMakefile( %makefile_attributes );

exit;

# --------------------------------------------------------------------------

sub Set_Install_Options
{
  my @args = @_;

  Verify_OK_To_Install();

  my $install_location = ExtUtils::MakeMaker::prompt(
    "Choose your installation type:\n[1] normal Perl locations\n" .
    "[2] custom locations\n=>" => '1');

  if ($install_location eq '2')
  {
    my $home = Get_Home_Directory();

    print "\n","-"x78,"\n\n";

    my $prefix = ExtUtils::MakeMaker::prompt(
      "What PREFIX should I use?\n=>" => $home);

    push @args,"PREFIX=$prefix";
  }

  return @args;
}

# --------------------------------------------------------------------------

sub Compute_Makefile_Attributes
{
  # Have to do this because MakeMaker and POSIX collide because someone used
  # @EXPORT when they should have used @EXPORT_OK. See
  # http://www.deja.com/=dnt_mn/getdoc.xp?AN=469218990&fmt=text
  unless (eval "require POSIX")
  {
    print "Warning: prerequisite POSIX 0 not found\n";
  }

  my %makefile_attributes = (
    'NAME'	=> 'CGI::Cache',
    'VERSION_FROM' => 'lib/CGI/Cache.pm',

    'PM'        => {
      'lib/CGI/Cache.pm' => '$(INST_LIB)/CGI/Cache.pm',
    },
    'PREREQ_PM' => { 'Storable' => 0, 'FileHandle::Unget' => 0, },
    'PREREQ_PM' => { 'File::Path' => 0,
                     'Tie::Restore' => 0,
                     'File::Spec' => 0,
                     'File::Spec::Functions' => 0,
                     'Cache::SizeAwareFileCache' => 0,
                     'Storable' => 0,
                     'IO::File' => 0,
    },
    'EXE_FILES' => [ ],
  );

  return %makefile_attributes;
}

# --------------------------------------------------------------------------

sub Verify_OK_To_Install
{
  if (eval "require CGI::Cache" && $CGI::Cache::VERSION <= 1.00)
  {
    print <<EOF;
WARNING!

The interface to CGI::Cache has changed substantially in this version. Any
scripts developed using previous versions CGI::Cache will NOT work. You are
seeing this message because an earlier, incompatible version of CGI::Cache has
been detected.

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

The interface to CGI::Cache has changed slightly in this version. Any scripts
developed using previous versions CGI::Cache will likely not work. You are
seeing this message because an earlier, incompatible version of CGI::Cache has
been detected.

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

