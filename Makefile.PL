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
                  'File::Path',
                  'Tie::Restore',
                  'File::Spec',
                  'Cache::Cache',
                  'Storable',
                );

include         ('ExtUtils/AutoInstall.pm');
auto_install    ( -default => 0 );

WriteAll();

print "\n", '-'x78, "\n\n";

exit;
