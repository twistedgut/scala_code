package Test::XTracker::Schema::ResultSet::Public::Container;

=head1 NAME

Test::XTracker::Schema::ResultSet::Public::Container - Test methods in the Container ResultSet

=head1 DESCRIPTION

Test methods in the Container ResultSet.

#TAGS fulfilment induction packing toobig needsrefactor

=head1 METHODS

=cut

use NAP::policy "tt", "test", "class";
use FindBin::libs;
BEGIN {
    extends "NAP::Test::Class";
    with(
        "Test::Role::WithSchema",
        "XTracker::Role::WithPRLs",
    );
};

use Test::XT::Fixture::PackingException::Shipment;
use XTracker::Config::Local qw( config_var );

use Test::XT::Data::Container;
use Test::XT::Fixture::Fulfilment::Shipment;


sub container_rs { shift->schema->resultset("Public::Container") }

=head2 in_commissioner

=cut

sub in_commissioner :Tests() {
    my ($self) = @_;

    # Clear out the Commissioner
    $self->container_rs->update({ place => undef });

    is(
        $self->container_rs->in_commissioner->count,
        0,
        "No containers in commissioner",
    );



    note "Setup one Container in the Commissioner";

    # Vanilla data object to instatiate fixture without a flow mech dependency
    my $data = Test::XT::Data->new_with_traits(
        traits  => [ 'Test::XT::Data::Order' ]
    );

    my $fixture = Test::XT::Fixture::PackingException::Shipment
        ->new({ pid_count => 1, flow => $data })
        ->with_picked_shipment
        ->with_picked_container_in_commissioner();
    is(
        $self->container_rs->in_commissioner->count,
        1,
        "One container found in commissioner",
    );

}

=head2 find_by_container_or_shipment_id

=cut

sub find_by_container_or_shipment_id : Tests() {
    my $self = shift;

    is(
        $self->container_rs->find_by_container_or_shipment_id("75345634"),
        undef,
        "find_by_container_or_shipment_id for missing id returns undef",
    );


    my $container_row = Test::XT::Data::Container->create_new_container_row();
    my $found_container_row
        = $self->container_rs->find_by_container_or_shipment_id(
            $container_row->id,
        );
    is(
        $container_row->id,
        $found_container_row->id,
        "Found Container by id",
    );
}

# Normalize datetimes
sub _dt {
    my ($datetime) = @_;
    return $datetime =~ s/ ([\d-]+) (.) ([\d:]+) .* /$1 $3/xr;
}

=head2 prepare_induction_page_data

    * 3 Containers with 2 staged shipments each (should be listed)
       ** one with normal SLA
       ** two with urgent SLA (with same exact sla cutoff)
    * 1 Container with 2 picked shipments (not listed)
    * 1 Container with nothing in it (not listed)

=cut

sub prepare_induction_page_data : Tests {
    my $self = shift;
    $self->prl_rollout_phase
        or return ok("SKIPPING: No staged allocations unless PRL");


    note "* Setup";
    my $new_fixture = sub { Test::XT::Fixture::Fulfilment::Shipment->new({
        pid_count => 2,
    }) };

    my @fixtures = (
        my $normal = $new_fixture->()->with_staged_shipment->with_normal_sla,
        my $urgent1 = $new_fixture->()->with_staged_shipment->with_urgent_sla,
        my $urgent2 = $new_fixture->()->with_staged_shipment->with_urgent_sla,
        $new_fixture->()->with_picked_shipment,
    );
    note "Set the sla_cutoff _exactly_ the same as the other one, to make
          sure the sort order is retained";
    $urgent2->shipment_row->update({
        sla_cutoff => $urgent1->shipment_row->sla_cutoff,
    });
    my ($empty_container_row) =
        map { $self->rs("Container")->find($_) }
        Test::XT::Data::Container->create_new_containers();
    my @container_rows = (
        $empty_container_row,
        map { $_->picked_container_row }
        @fixtures
    );

    # Limit the test resultset to the test data so we don't
    # accidentally include other Containers
    my $container_rs = $self->rs("Container")->search({
        "me.id" => { -in => [ map { $_->id } @container_rows ] },
    });


    note "* Run";
    my $induction_records = $container_rs->prepare_induction_page_data();

    note "*Test ";
    my $urgent1_container_row = $urgent1->picked_container_row;
    my $urgent2_container_row = $urgent2->picked_container_row;
    my $normal_container_row = $normal->picked_container_row;
    eq_or_diff(
        [
            map {
                +{
                    shipments_summary => $_->{shipments_summary},
                    cutoff            => _dt($_->{cutoff}),
                }
            }
            @$induction_records,
        ],
        [
            {
                shipments_summary => $urgent1_container_row->shipments->first->id . ": 2 items",
                cutoff            => _dt($urgent1_container_row->shipments->first->sla_cutoff),
            },
            {
                shipments_summary => $urgent2_container_row->shipments->first->id . ": 2 items",
                cutoff            => _dt($urgent2_container_row->shipments->first->sla_cutoff),
            },
            {
                shipments_summary => $normal_container_row->shipments->first->id . ": 2 items",
                cutoff            => _dt($normal_container_row->shipments->first->sla_cutoff),
            },
        ],
        "induction_records as expected",
    );


    ok(1);
}

