#!/usr/bin/env perl
#
# This test searches for template files in the distribution, and
# attempts to parse them, to make sure there are no syntax errors.
#
# It will miss some potential template failures (missing include
# files, while loops that go on too long, etc) because it doesn't
# attempt to process the templates, just parse them.

use NAP::policy "tt", 'test';

use File::Find::Rule;
use File::Slurp;
use Template::Parser;

my $parser = Template::Parser->new();

# Get a list of all template files in the distribution.
# If you know of any templates that won't be found by
# this, please update the rule.
my $d = $ENV{'XTDC_BASE_DIR'};
my @files = File::Find::Rule
    ->file()
    ->name( qr/\.(tt)$/ )
    ->in( "$d/t", "$d/conf", "$d/root/base" );

note(scalar(@files) . " template files to parse");

# Try to parse each file, hope for no errors.
for my $file (sort @files) {
    my $text = read_file($file);
    my $success = $parser->parse($text);
    is($parser->error(), "", "$file parsed successfully");
}

done_testing;

1;
