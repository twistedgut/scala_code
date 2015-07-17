package PRL::Migration::Utils;

use NAP::policy;
use File::Basename              qw( basename dirname );
use File::Slurp                 qw( read_file write_file );
use File::Spec::Functions       qw( catfile );
use List::AllUtils              qw( any );
use Text::CSV_XS                qw( csv );
use XTracker::Constants         qw( $APPLICATION_OPERATOR_ID );
use XTracker::Constants::FromDB qw( :allocation_status :customer_issue_type );
use XTracker::Database          qw( xtracker_schema );

=head1 NAME

PRL::Migration::Utils - utilities for the PRL migration

=head1 SYNOPSIS

    use PRL::Migration::Utils;

    my $retry_file = PRL::Migration::Utils->rewrite_allocation_prl(
        '/path/to/dbdump.fulfilment.first.csv'
    );

=head1 DESCRIPTION

A collection of utilities to help with the PRL migration scripts.

=head1 METHODS

=head2 rewrite_allocation_prl( Str $dbdump_file ) -> Str $retry_file | Undef

Rewrite the prl of the allocation in the provided I<$dbdump_file>.

The I<$dbdump_file> is the output of the I<dc2_full_to_goh.sh> PRL migration
script. See sample runs at the Jenkins job:

* http://build01.wtf.nap/job/PRL_Full_to_GOH_migration

Returns:

* I<undef> - if all allocations were successfully re-allocated
* File containing dbdump data for allocations that failed so you can retry

The failures would be a result of the I<allocate_response> not being processed
in time.

=cut

sub rewrite_allocation_prl {
    my ( $class, $dbdump_file, $retry_file ) = @_;

    die "No database dump file provided\n" unless -e $dbdump_file;

    say 'rewrite_allocation_prl( ... )';

    my $dbdump_data  = csv( in => $dbdump_file, headers => 'auto' );
    my @shipment_ids = $class->reallocate_shipments(
        $class->cancel_allocation_items_from(
            map { $_->{allocation_id} } @{ $dbdump_data }
        )
    ) or return undef;

    my @allocation_ids = xtracker_schema->resultset('Public::Allocation')
        ->search({ shipment_id => [@shipment_ids] })
        ->get_column('id')
        ->func('distinct');

    my %dbdump_data_for = map  { $_->{allocation_id} => $_ } @{ $dbdump_data };
    my @retry_data      = grep { defined }
                          map  { $dbdump_data_for{$_} } @allocation_ids;

    if (@retry_data) {
        $retry_file //= catfile(
            dirname( $dbdump_file ),
            join( '.', 'retry', basename $dbdump_file ),
        );

        say sprintf 'There are %i allocations to retry.' => scalar @retry_data;
        say "Please rerun with $retry_file in place of $dbdump_file";

        csv(
            eol     => $/,
            headers => [ keys %{ $dbdump_data->[0] } ],
            in      => [ @retry_data ],
            out     => $retry_file,
        );
    }

    return $retry_file;
}

=head2 cancel_allocation_items_from( Array[Int] @allocation_ids ) -> Array[Int] @shipment_ids

Cancel the allocation items on the allocations in the I<$dbdump_file>.

Returns the unique shipment ids affected.

=cut

sub cancel_allocation_items_from {
    my ( $class, @allocation_ids ) = @_;

    say 'cancel_allocation_items_from( ... )';

    # get the allocations ...
    my $allocation_rs = xtracker_schema
        ->resultset('Public::Allocation')->search({ id => [@allocation_ids] });

    say sprintf 'XT knows about (%i) allocations' => $allocation_rs->count;

    # cancel the allocation items (saving the shipment ids)...
    while ( my $allocation = $allocation_rs->next ) {
        try   { $allocation->cancel_allocation_items }
        catch {
            warn sprintf(
                'Failed to cancel allocation items for allocation: (%i)',
                $allocation->id,
            );
        };
    }

    # return the unique shipment ids ...
    return $allocation_rs->get_column('shipment_id')->func('distinct');
}

=head2 reallocate_shipments( Array[Int] @shipment_ids ) -> Array[Int] @shipment_ids

Re-allocate the I<@shipment_ids> specified.

Returns the I<@shipment_ids> for any shipments that were not updated because the
I<allocate_response> has not been received.

=cut

sub reallocate_shipments {
    my ( $class, @shipment_ids ) = @_;

    say 'reallocate_shipments( ... )';

    # fetch the shipments ...
    my $shipment_rs = xtracker_schema->resultset('Public::Shipment')->search(
        { 'me.id'  => [@shipment_ids] },
        { prefetch => ['allocations'] },
    );

    say sprintf 'XT knows about (%i) shipments' => $shipment_rs->count;

    # track shipments not updated ...
    my %not_updated;

    # allocate the shipments ...
    while ( my $shipment = $shipment_rs->next ) {
        if ( any { !$_->is_allocated } $shipment->allocations ) {
            $not_updated{ $shipment->id }++;
            next;
        }

        try {
            $shipment->allocate({ operator_id => $APPLICATION_OPERATOR_ID })
        }
        catch { $not_updated{ $shipment->id }++ };
    }

    return keys %not_updated;
}

=head2 rewrite_amq_config_file( File $config_file ) -> 1 | Undef

Re-write the AMQ messaging config file to remove all but the PRL instances.

=cut

sub rewrite_amq_config_file {
    my ( $class, $config_file ) = @_;

    my $old_config = read_file $config_file;
    my $instances  = <<'INSTANCES';
 <instances>
  name "Measurements and non-split WMS"
  destination /queue/dc2/xt_prl
  instances 1
 </instances>
INSTANCES

    write_file(
        $config_file,
        $old_config =~ s{<runner>(.+)<\/runner>}{<runner>\n$instances</runner>}rs,
    );
}

1;
