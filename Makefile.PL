#!/usr/bin/perl

use strict;
use inc::Module::Install;

Check_Custom_Installation();

print "\n", '-'x78, "\n\n";

name            ('CGI-Cache');
author          ('David Coppit <david@coppit.org>');
abstract_from   ('lib/CGI/Cache.pm');
version_from    ('lib/CGI/Cache.pm');
license         ('gpl');

requires        (
                  'File::Path' => 0,
                  'Tie::Restore' => 0,
                  'File::Spec' => 0,
                  'Cache::Cache' => 0,
                  'Storable' => 0,
                );

include         ('ExtUtils/AutoInstall.pm');

auto_install    ( );
WriteAll();

print "\n", '-'x78, "\n\n";

exit;
