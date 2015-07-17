#!/usr/bin/env perl

use NAP::policy "tt";
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::PrintFunctions 'path_for_document_name';

# Simple script to return the printdocs path for a given document filename

my @document_paths = map { path_for_document_name( $_ ) } @ARGV;

print join(' ', grep { defined && length } @document_paths), "\n";
