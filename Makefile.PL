use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'CGI::Cache',
    'VERSION_FROM' => 'Cache.pm', # finds $VERSION
    'PREREQ_PM'   => { 'File::Cache' => 0, 'LWP' => 0 }
);
