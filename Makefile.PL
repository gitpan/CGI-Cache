#!/usr/bin/perl

use strict;
use inc::Module::Install;

all_from        ('lib/CGI/Cache.pm');

requires        (
                  'File::Path' => 0,
									'Tie::Restore' => 0,
									'File::Spec' => 0,
									'Cache::Cache' => 0,
									'Storable' => 0,
                );

test_requires   (
                  'Test::More' => 0,
                );

clean_files       ('t/CGI_Cache_tempdir','t/*.cgi');

WriteAll();
