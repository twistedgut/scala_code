package Test::XT::Flow::Easy;

=head1 NAME

Test::XT::Flow::Easy

=head1 DESCRIPTION

Unfinished but usable module for "just give me a flow method"

=head1 USAGE

 use Test::XT::Flow::Easy;

 $flow
    ->flow_mech__stockcontrol__inventory_stockquarantine( $product->id );

=head1 DISCUSSION

Attempts to give you a fully-loaded C<$flow> object. People appear to be
cargo-culting much of the setup anyway, and so this just gives you everything
you might need.

It's only currently used in one module, which has some absolutely crazy-town
mixing of it and another Flow object in it, and which also demonstrates that
this can be used to load RunConditions, fine-grain permissions, etc.

This module is a good idea, but it needs a few heroes to start using it and
then document the features it offers.

=cut

# So, you're going to cargo-cult your tests eh? Better make sure you don't break
# too much doing it :-/

use NAP::policy "tt", 'test';

use parent 'Exporter';
our @EXPORT_OK = qw( $flow );

use Test::XT::Flow;
use Test::XTracker::Data;
use XTracker::Constants::FromDB qw( :authorisation_level :flow_status  );
use XTracker::Database qw(:common);

our $flow;

sub import {
    my ( $class, %stuff ) = @_;

    if ( my $run_conditions = delete $stuff{'runconditions'} ) {
        require Test::XTracker::RunCondition;
        Test::XTracker::RunCondition->import( @$run_conditions, export_level => 2 );
    }

    # Lovingly stolen from NAP::policy in case the user of the module hasn't
    # specified it themselves
    my $caller = caller;
    eval <<"MAGIC" or die "Couldn't set up testing policy: $@"; ## no critic(ProhibitStringyEval)
        package $caller;
        use Test::Most '-Test::Deep';
        use Test::Deep '!blessed';
        use Test::XTracker::Data;
        use Data::Printer;
    1;
MAGIC

    # No harm in just sucking everything in
    unless ( $flow ) {
        $flow = Test::XT::Flow->new_with_traits(
            traits => [
                # Use ALLLLLLL of them
                'Test::XT::Data::Location',
                'Test::XT::Flow::Fulfilment',
                'Test::XT::Flow::GoodsIn',
                'Test::XT::Flow::StockControl::Quarantine',
                'Test::XT::Flow::RTV',
                'Test::XT::Feature::AppMessages',
                'Test::XT::Feature::LocationMigration',
                'Test::XT::Flow::WMS'

            ],
        );

        # Figure out permissions... If anyone asks, you never saw this, k?
        my $bad_idea = $flow->dbh->prepare("
            SELECT section.section ||'/'|| subsection.sub_section AS holy_moly_cowboy
            FROM authorisation_section section, authorisation_sub_section subsection
            WHERE subsection.authorisation_section_id = section.id
            AND section=?");

        my @long_hand_permissions = map {
            my $section_name = $_;
            $bad_idea->execute( $section_name );
            map { $_->[0] } @{ $bad_idea->fetchall_arrayref() || [] }
        } @{$stuff{'permissions'}||[]};

        $flow->login_with_permissions({
            perms => { $AUTHORISATION_LEVEL__MANAGER => \@long_hand_permissions }
        });

        note 'Clearing all test locations';
        $flow->data__location__destroy_test_locations;
    }

    $class->export_to_level( 1, $class, qw/$flow/ );
}

1;
