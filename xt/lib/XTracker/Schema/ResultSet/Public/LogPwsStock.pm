package XTracker::Schema::ResultSet::Public::LogPwsStock;
use NAP::policy "tt";

use MooseX::Params::Validate;
use MooseX::Types::Common::Numeric qw/PositiveInt/;
use Moose::Util::TypeConstraints;
use Carp qw/ croak cluck /;

use XTracker::Constants qw( :application );
use XTracker::Constants::FromDB qw(
    :pws_action
);
use XTracker::Database::Stock;
use XTracker::EmailFunctions qw( send_email );
use XTracker::Config::Local qw( config_var );
use NAP::XT::Exception::Internal;

use base 'DBIx::Class::ResultSet';

=head2 C<log_order>

    $log_pws_stock_rs->log_order( $item );

Create an entry in the log_pws_stock table of a -1 reduction of the stock of the
item being ordered.

=cut

sub log_order {
    my ( $self, $item ) = @_;

    croak 'Shipment item row required'
        unless $item and ref $item eq 'XTracker::Schema::Result::Public::ShipmentItem';

    my $variant_id = (
        defined $item->variant_id
        ? $item->variant_id
        : $item->voucher_variant_id
    );

    $self->log_stock_change({
        variant_id => $variant_id,
        channel_id => $item->shipment->order->channel->id,
        pws_action_id => $PWS_ACTION__ORDER,
        quantity => -1,
        notes => $item->shipment->id,
    });

}

=head2 C<log_stock_change>

    $log_pws_stock_rs->log_stock_change({
        variant_id      => 1,
        channel_id      => 1,
        pws_action_id   => 1,
        quantity        => 1,
        notes           => 'Stock Change',
        operator_id     => 1,
    })

Log a stock change for a variant. c<operator_id> will default to the application
operator id if not provided.

=cut

sub log_stock_change {
    my ($self, $variant_id, $channel_id, $pws_action_id, $quantity, $notes, $operator_id)
    = validated_list(\@_,
        variant_id      => { isa => PositiveInt },
        channel_id      => { isa => PositiveInt },
        pws_action_id   => { isa => subtype({
            as      => PositiveInt,
            where   => sub {
                my $action_id = $_;
                grep { $action_id == $_ } @PWS_ACTION_VALUES;
            },
        })},
        quantity        => { isa => 'Int' },
        notes           => { isa => 'Str', optional => 1 },
        operator_id => {
            isa         => 'Int',
            optional    => 1,
            default     => $APPLICATION_OPERATOR_ID,
        },
    );

    my $dbh = $self->result_source->schema->storage->dbh;

    # If we're doing an upload then we need to check for duplicate log entries
    $self->_check_duplicate_log_upload_entry($variant_id, $channel_id, $operator_id)
        if $pws_action_id == $PWS_ACTION__UPLOAD;

    # XXX refactor to DBIC call?
    # This returns a the current sellable + reserved stock count for the item#

    # using full path for method call here so the code plays nice with tests
    # (Can't mock a method that has been exported :/ as it will do it AFTER
    # the export has taken place)
    my $free_stock = XTracker::Database::Stock::get_total_pws_stock( $dbh, {
        type => 'variant_id',
        id => $variant_id,
        channel_id => $channel_id,
    } );
    my $current_stock = $free_stock->{$variant_id}->{quantity};

    # Log the stock change
    return $self->create({
        variant_id      => $variant_id,
        pws_action_id   => $pws_action_id,
        operator_id     => $operator_id,
        quantity        => $quantity,
        balance         => $current_stock,
        notes           => $notes,
        channel_id      => $channel_id,
    })->id();

}

sub _check_duplicate_log_upload_entry {
    my ($self, $variant_id, $channel_id, $operator_id) = @_;

    my $variant = $self->result_source->schema->resultset('Public::Variant')->find($variant_id);
    NAP::XT::Exception::Internal->throw(
        sprintf('Variant with id %s can not be found', $variant_id)
    ) unless $variant;

    my $log_entries = $variant->log_pws_stocks->search({
        pws_action_id   => $PWS_ACTION__UPLOAD,
        channel_id      => $channel_id,
    })->count();

    return unless $log_entries;

    my $message = "duplicate log_pws_stock request for variant_id=$variant_id, channel_id=$channel_id, operator_id=$operator_id";

    # put something in the logs
    cluck($message);

    # and send an email to someone who cares
    my $subject_line  = "Duplicate log_pws_stock() request: variant_id=$variant_id; action=Upload";
    my $email_address = config_var('Email', 'xtracker_email');

    send_email(
        $email_address, # from
        $email_address, # reply-to
        config_var('job_queue', 'failed_job_email_to'), # goes to JIRA usually
        $subject_line,
        Carp::longmess($message)
          . "\n\n[ http://jira.nap/browse/EN-2239 ]",
    );
}

1;
