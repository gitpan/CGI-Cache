#!/usr/bin/perl

use strict;
use inc::Module::Install;

name              ('CGI-Cache');
author            ('David Coppit <david@coppit.org>');
abstract_from     ('lib/CGI/Cache.pm');
version_from      ('lib/CGI/Cache.pm');
license           ('gpl');

build_requires    (
                    'Test::More' => 0,
                    'File::Path' => 0,
                  );
requires          (
                    'perl' => 5.004,
                    'File::Path' => 0,
                    'Tie::Restore' => 0,
                    'File::Spec' => 0,
                    'Cache::Cache' => 0,
                    'Storable' => 0,
                  );

clean_files       ('t/CGI_Cache_tempdir','t/*.cgi');

include           ('ExtUtils/AutoInstall.pm');

auto_include_deps ( );
auto_install      ( );

WriteAll();

print "\n", '-'x78, "\n\n";

exit;
