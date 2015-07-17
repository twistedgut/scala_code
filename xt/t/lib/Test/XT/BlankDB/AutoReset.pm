package Test::XT::BlankDB::AutoReset;

use strict;
use warnings;

use Test::XTracker::Data;
use XTracker::Config::Local qw(config_var);
use Test::XT::BlankDB;
use XTracker::Schema;

=head1 NAME

Test::XT::BlankDB::AutoReset

=head1 SYNOPSIS

  HARNESS_PERL_SWITCHES='-Mlib=t_phase_1/lib -MTest::XT::BlankDB::AutoReset' \
   prove -lr t_phase_1/

=head1 DESCRIPTION

Reset out DB if we're set up correctly to do it. "Set up correctly to
do it" means we have a reference database findable in the config and
the target DB looks like a blank DB. Also check for
C<$ENV{NO_BLANK_DB_RESET}>.

=cut

# Bail-out if we find NO_BLANK_DB_RESET
if ( $ENV{'NO_BLANK_DB_RESET'} ) {
    note "NO_BLANK_DB_RESET set";
    goto DONE;
}

# See if we can find a reference connection config set
unless ( config_var('Database_reference','db_name') ) {
    note "No reference database defined";
    goto DONE;
}

# Get the 'target' connection, and check it's a blank db
my $target = XTracker::Schema->connect(
    'dbi:Pg:dbname=' . config_var('Database_xtracker','db_name')
        . ';host=' . config_var('Database_xtracker','db_host'),
    'postgres','',
    {
        AutoCommit => 1,
        PrintError => 0,
        RaiseError => 1,
    },
);

# Check it's a blank DB
unless ( Test::XT::BlankDB::check_blank_db( $target ) ) {
    note "Target DB isn't marked as 'blank'";
    goto DONE;
}

eval {
    # Attempt to connect a schema to the reference database
    my $source = XTracker::Schema->connect(
        'dbi:Pg:dbname=' . config_var('Database_reference','db_name')
            . ';host=' . config_var('Database_reference','db_host'),
        config_var('Database_reference','db_user'),
        config_var('Database_reference','db_pass'),
        {
            AutoCommit => 1,
            PrintError => 0,
            RaiseError => 1,
        },
    );

    if ($source) {
        Test::XT::BlankDB::reset_database( $source, $target );
    }
};
diag $@ if $@;

DONE: 1;
