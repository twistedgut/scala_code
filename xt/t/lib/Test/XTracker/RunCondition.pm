package Test::XTracker::RunCondition;

use NAP::policy "tt", 'test';

use Test::XTracker::LoadTestConfig;
use XTracker::Config::Local qw( config_var );

use parent 'Exporter';
our @EXPORT_OK = qw( $iws_rollout_phase $prl_rollout_phase $distribution_centre );

my %valid                  =  (
    phase                  => { map { $_ => 1 } qw( 0 1 2 iws all ) },
    iws_phase              => { map { $_ => 1 } qw( 0 1 2 iws all ) },
    prl_phase              => { map { $_ => 1 } qw( 0 1 2 prl all ) },
    iws_or_prl             => { map { $_ => 1 } qw ( 0 1 ) },
    pick_scheduler_version => { map { $_ => 1 } qw( 1 2 all ) },
    dc                     => { map { $_ => 1 } qw( DC1 DC2 DC3 all ) },
    export                 => { iws_rollout_phase => 1, distribution_centre => 1, prl_rollout_phase => 1 },
    database               => { map { $_ => 1 } qw( blank full all ) },
    show_status            => { 1 => 1},
    export_level           => [ 1 .. 99 ]
);

# Set during import()
our $iws_rollout_phase      = config_var('IWS', 'rollout_phase');
our $prl_rollout_phase      = config_var('PRL', 'rollout_phase');
our $distribution_centre    = config_var('DistributionCentre','name');
our $pick_scheduler_version = config_var('PickScheduler','version') // 0;

=head1 NAME

Test::XTracker::RunCondition

=head1 DESCRIPTION

Specify which DCs and architectures your test is compatible with

=head1 SYNOPSIS

 # All the magic happens when you 'use' this module
 use Test::XTracker::RunCondition
    iws_phase  => [1, 2],
    dc     => 'all',
    export => [qw( $iws_rollout_phase $distribution_centre )];

=head1 WHY

Many tests used to start by trying to work out what DC they were in, and only
continuing to run if they were in an appropriate one. There were a variety of
interesting techniques used for this, and that sort of worked.

But then we also became dependent on which I<architecture> a test was running
under - was the test expecting IWS to be operational? Then we configured the
blank database, and some tests were far too dependent on a whole database to be
able to be used with it.

Essentially then we eneded up with a whole host of conditions that tests might
or might not run under. What's more, quite a few tests would run under all the
different scenarios, but wanted to do different things depending on them, and
were calling out to the config, or trying to figure out the state of the
database.

This module provides a consistent way of insisting on certain conditions for a
test to run, and additionally exports some information about the environment
that a test can make use of.

=head1 TEST::CLASS

This module should work seamlessly with L<Test::Class>. Darius and Johan have
previously fixed it when it hasn't done, so may be able to provide further
guidance.

=head1 DON'T LOAD XTRACKER::SCEHMA

This module goes out of its way to avoid loading L<XTracker::Schema> on normal
runs, because there's a significant load-time penalty with including it. If
you're planning to extend this module, please make sure you only load it when
required, and thus obviously only include modules that rely on it if absolutey
required.

=head1 USAGE

=head2 Choosing Your Options

In general, choose the most liberal set of options your test will run under.
If your test exercises conditions that are differ between different DCs or
architectures, consider making it handle both.

Almost all new tests should be able to run under any database. Making it run
only under I<blank> risks it being too fragile to handle broken data left by
previous test runs, and making it run only under I<full> suggests that we need
to extend the blank database to include relevant reference tables - but also,
most developers only run their tests with a blank database, and so the test
will frequently be skipped.

=head2 Configuration Options

The payload of this module is run when you C<use> it, and that's also when you
provide it with arguments. The C<import()> method is run with the arguments
that you provide.

If you don't provide arguments for a key, then that condition is simply left
unchecked.

Possible keys are:

=head3 iws_phase

Accepts a single argument or arrayref of arguments. Currently accepts any of
C<0>, C<1>, C<2>, C<iws> or C<all>. C<iws> is translated to (1, 2). You can
specify as many as you like, or not use this key to not specify.

=head3 prl_phase

Accepts a single argument of C<0>, for off, C<1> for PRL rollout phase 1,
C<prl> to signal all future non-zero phases, and C<all> which specifies that
you don't mind (which is the same as just not specifying a C<prl_phase>).

=head3 iws_or_prl

Accepts a single argument of C<0>, for off, C<1> for on. On implies
either iws_rollout_phase = 2 or prl_phase = 1 without both having to
be set.

=head3 pick_scheduler_version

Accepts a single argument of C<1> or C<1> and C<all> which specifies
that you don't mind (which is the same as just not specifying one).

=head3 phase

Old and deprecated alias to C<iws_phase>.

=head3 dc

Accepts a single argument or arrayref of arguments. Currently accepts any of
C<DC1>, C<DC2>, C<DC3> or C<all>. You can specify as many as you like, or not
use this key to not specify.

=head3 database

Accepts a single argument or arrayref of arguments. Currently accepts any of
C<blank>, C<full> or C<all>. We derive the state of the DB as:

 Test::XT::BlankDB::check_blank_db( Test::XTracker::Data->get_schema )
   ? 'blank' : 'full'

=head3 export

Accepts a single argument or arrayref of arguments. Accepts
C<$iws_rollout_phase>, C<$prl_rollout_phase> and C<$distribution_centre>, and
exports scalar values from the config for them in to your script.

=cut


sub import {
    my ( $class, %constraint ) = @_;

    for my $key ( keys %constraint ) {
        die "Unknown option $key" unless $valid{ $key };
    }

    $constraint{'database'} = 1 if $constraint{'show_status'};

    # What's the current state?
    my %current_state = (
        iws_phase              => $iws_rollout_phase,
        phase                  => $iws_rollout_phase,
        prl_phase              => $prl_rollout_phase,
        pick_scheduler_version => $pick_scheduler_version,
        dc                     => $distribution_centre,
        iws_or_prl             => ($iws_rollout_phase > 0 || $prl_rollout_phase == 1),
        # Lazy eval this only if required...
        database               => (
            exists $constraint{'database'} &&
            $constraint{'database'} ne 'all' ) ?
                db_type() : 'whatever'
    );

    # Let the user know
    note 'Running ' .
        'in iws phase [' . $current_state{'iws_phase'}    . '] ' .
        'in prl phase [' . $current_state{'prl_phase'}    . '] ' .
        'in dc ['    . $current_state{'dc'}       . '] ' .
        'with a ['   . $current_state{'database'} . '] database ' .
        'with pick_scheduler_version [' . $current_state{'pick_scheduler_version'} . ']';

    # Phase 1?!
    if ( $current_state{'iws_phase'} == 1 ) {
        gotcha("Running in Phase 1");
    }

    return if $constraint{'show_status'};

    # Sanity-check our inputs
    my $found_key;

    foreach my $key (qw( iws_phase phase dc database prl_phase iws_or_prl pick_scheduler_version)) {
        next unless exists $constraint{ $key };
        $found_key++;

        if ($key eq 'phase') {
            fail("RunCondition 'phase' is deprecated; use 'iws_phase' instead");
        }

        # Flatten out any arrayrefs
        my @options = ref( $constraint{ $key } ) ?
            @{ $constraint{ $key } } : ( $constraint{$key} );
        croak "You specified an empty list for $key" unless @options;

        # Search for any bad ones
        for my $option ( @options ) {
            croak "[$option] is not a valid value for $key"
                unless $valid{$key}->{$option};
        }

        # Free pass on 'all'
        if ( grep { $_ eq 'all' } @options ) {
            Carp::carp("Please don't use 'all' in your run conditions - this has been deprecated");
            next;
        }
        @options = (1, 2) if grep { $_ eq 'iws' } @options;
        @options = (1, 2) if grep { $_ eq 'prl' } @options;

        # Can we find the exact one?
        unless ( grep { $current_state{ $key } eq $_ } @options) {

            my $skip_msg = sprintf(
                "This test does not run in $key [%s] - it only runs in ${key}s: [%s]",
                $current_state{ $key },
                (join '], [', @options)
            );

            # If I'm being loaded by a Test::Class module, do something a bit
            # more sensible
            if ( $INC{'Test/Class/Load.pm'} ) {
                my $calling_package = (caller)[0];
                note "Skipped by RunCondition [$calling_package]: $skip_msg";
                # Subclass may not have happened yet, so we can't call the
                # calling packages SKIP_CLASS, so we cheat and do it this way
                Test::Class::SKIP_CLASS( $calling_package, $skip_msg );
            } else {
                Test::Builder->new->skip_all( $skip_msg );
            }
        }
    }

    # Export anything the user wanted
    my @exports = (
        defined $constraint{'export'} ? (
            ref( $constraint{'export'} ) ?
                @{ $constraint{'export'} } :
                ( $constraint{'export'} ) ) :
            ());
    croak "You didn't specify restrictions (IWS phase, PRL phase, DC, or database) or exports"
        if !$found_key && !@exports;
    $class->export_to_level( $constraint{'export_level'} || 1, $class, @exports);
}

=head1 METHODS

=head2 db_type

Returns C<blank> or C<full>, depending

=cut

sub db_type {
    # Pulls in XTracker::Schema, so we're careful about loading it
    require Test::XTracker::Data;
    require Test::XT::BlankDB;
    Test::XT::BlankDB::check_blank_db( Test::XTracker::Data->get_schema ) ?
        'blank' : 'full';
}

# This is called if people are running IWS in Phase 1, which is deprecated
sub gotcha {
    my ( $infraction ) = @_;
    die "XT should not currently be running in Phase 1 - please fix and try again.";
}

=head1 SEE ALSO

L<Test::XTracker::RunCondition::Find> contains code to examine test files to
see if they have RunConditions, and if so, which. This is useful if you're
writing tools to try and locate certain classes of test file.

=cut

1;
