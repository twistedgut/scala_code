package Test::XT::Data::Container;

use NAP::policy "tt", 'test';

use Carp qw/ croak /;


use Test::XTracker::Data;
use Test::XT::Fixture::Fulfilment::Shipment;

use XTracker::Constants::FromDB qw/:container_status/;
use XTracker::Config::Local qw( config_var );
use NAP::DC::Barcode::Container;

=head2 get_unique_ids

Get list of L<NAP::DC::Barcode::Container> object that represent
unique container IDs.

how_many - Optional, determine how many IDs to return. Default one in 1.

prefix - Optional, string with prefix for IDs to be produced. Result
IDs are "prefix" followed by 3 digits, making it a total of 7 digits
to conform with the valid barcode formats.

final_digit_length - Optional, number of digit in result barcode.
As it could be different for some barcode types, e.g. for totes it is 7,
for hooks it is 4.
Defaults to 7.

Defaults to B<T0123>, unless IWS is in use (IWS insists on M style
barcodes) in which case the default is "M0123".

=cut

sub get_unique_ids {
    my ($self,$args) = @_;

    my $how_many           = $args->{how_many} || 1;
    my $final_digit_length = $args->{final_digit_length} // 7;

    my $prefix   = $args->{prefix} || do {
        my $iws_rollout_phase = config_var('IWS', 'rollout_phase');
        my $default_prefix = $iws_rollout_phase
            ? "M12"
            : "T12";
    };
    my ($prefix_chars, $prefix_number) = ($prefix =~ /^ ([A-Z]+) (\d+)?/x)
        or croak("Malformed prefix ($prefix)\n");
    $prefix_number //= "";

    my $missing_digit_length = $final_digit_length - length($prefix_number);
    if($missing_digit_length <= 0) {
        croak("Please use at most 4 digits in the prefix");
    }

    my $missing_digit_like_pattern = "_" x $missing_digit_length; # _ matches a digit

    my $last_item = Test::XTracker::Data->get_schema
        ->resultset('Public::Container')
        ->search(
            {
                id => { ilike => "$prefix$missing_digit_like_pattern" }
            },
            {
                order_by => {'-desc' => 'id'}
            }
        )->slice(0,0)->first;

    my $last_id = $last_item ? $last_item->id : '';
    $last_id =~ s/^$prefix//;
    $last_id =~ s/\D//g;
    $last_id ||= 0;

    my @container_ids = ();

    foreach my $count (1..$how_many){
        my $container_id = $prefix_chars . sprintf(
            "%0${final_digit_length}d",
            $prefix_number . sprintf("%0${missing_digit_length}d", $last_id + $count),
        );
        note "Test container: ($container_id)";

        push(
            @container_ids,
            NAP::DC::Barcode::Container->new_from_id($container_id),
        );
    }

    return @container_ids;
}

=head2 get_unique_id($args) : Barcode::Container $container_id

Like get_unique_ids, but always returns a single object.

=cut

sub get_unique_id {
    my ($self, $args) = @_;
    $args //= {};
    my @ids = $self->get_unique_ids({
        %$args,
        how_many => 1,
    });
    return $ids[0];
}

=head2 create_new_containers(:$status = available, :$how_many = 1) : $container_ids | @container_ids

Adds new containers into system.

It accepts same set of arguments as L<get_unique_ids> with one
optional parameter:

C<status> : status for newly created containers. If not provided,
"available" one is used.

B<Return>

Depending on context, array or arrayref of newly created container barcodes
(L<NAP::DC::Barcode::Container> objects).

=cut

sub create_new_containers {
    my ($self, $args) = @_;

    my @new_container_rows = $self->create_new_container_rows($args);
    my @new_ids = map { $_->id } @new_container_rows;

    return wantarray ? @new_ids : \@new_ids;
}

=head2 create_new_container_rows( ... ) : $container_rows | @container_rows

Same as ->create_new_containers(...), but returns DBIC Container rows
instead.

=cut

sub create_new_container_rows {
    my ($self, $args) = @_;

    # get status of new containers
    my $status = delete $args->{status};

    # if it is not provided fall back to default one
    $status //= $PUBLIC_CONTAINER_STATUS__AVAILABLE;

    my @new_ids = $self->get_unique_ids($args);

    my $schema = Test::XTracker::Data->get_schema;

    my @new_container_rows =
        grep { defined }
        map {
            $schema->resultset('Public::Container')->create({
                id        => $_,
                status_id => $status,
            });
        }
        @new_ids;

    if ($args->{with_shipment_item}) {
        foreach my $container (@new_container_rows) {
            my $fixture = Test::XT::Fixture::Fulfilment::Shipment->new({
                pid_count => 1,
            })->with_selected_shipment;

            $container->add_picked_item({
                shipment_item => $fixture->shipment_row->shipment_items->first
            });
        }
    }

    return wantarray ? @new_container_rows : \@new_container_rows;
}

=head2 create_container_row(:$status = available) : $container_row

Return a single, newly created $container_row in $status.

=cut

sub create_new_container_row {
    my ($self, $args) = @_;
    $args //= {};

    $args->{how_many} = 1;
    my ($container_row)
        = Test::XT::Data::Container->create_new_container_rows($args);

    return $container_row;
}

1;

