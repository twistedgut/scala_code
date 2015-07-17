#!/opt/xt/xt-perl/bin/perl

# A simple wrapper around Test::XT::BlankDB::reset_database

use strict;
use warnings;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use Getopt::Long::Descriptive;
use Carp qw(croak);
use XTracker::Schema;
use Test::XT::BlankDB;

my ($opt, $usage) = describe_options(
    'create_blank_db.pl %o',
    [ 'source|s=s', "Name of reference DB", { required => 1 } ],
    [ 'source_host|S=s', "Hostname of reference DB", { default => 'localhost' } ],
    [ 'target|t=s', "Name of output DB (will be wiped)", { required => 1 } ],
    [ 'target_host|T=s', "Hostname of output DB (will be wiped)", { default  => 'localhost' } ],

    [],
    [ 'help',       "print usage message and exit" ],
);

print($usage->text), exit if $opt->help;

my $source=get_schema($opt->{source},$opt->{source_host});
my $target=get_schema($opt->{target},$opt->{target_host});

Test::XT::BlankDB::reset_database( $source, $target );

sub get_schema {
    my ($db,$host)=@_;

    return XTracker::Schema->connect(
        "dbi:Pg:dbname=$db;host=$host",
        'postgres','',
        {
            AutoCommit => 1,
            PrintError => 0,
            RaiseError => 1,
        },
    );
}
