package XTracker::Script::PreOrder::InformWebsite;

use NAP::policy "tt", 'class';
extends 'XT::Common::Script';
with 'XTracker::Role::WithAMQMessageFactory';

with map { "XTracker::Script::Feature::$_" } qw(
    SingleInstance
    Schema
    Logger
);

sub log4perl_category { return 'PreOrder' }

use XT::DC::Messaging::Producer::PreOrder::TriggerWebsiteOrder;

use XTracker::Config::Local     qw( config_var );
use XTracker::Constants::FromDB qw( :pre_order_item_status
                                    :pre_order_status
                                  );

=head1 NAME

  XTracker::Script::PreOrder::InformWebsite

=head1 SYNOPSIS

  XTracker::Script::PreOrder::InformWebsite->invoke();

=head1 DESCRIPTION

  Gather all preorders with available items, generate a message to inform the
  web site of these and update the item and preorder statuses to reflect the
  exported status.

=cut

has preorders_for_export => (
    is          => 'ro',
    isa         => 'XTracker::Schema::ResultSet::Public::PreOrder',
    lazy_build  => 1,
);

has verbose => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has dryrun => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

around BUILDARGS => sub {
    my ($orig,$self,@args) = @_;

    my $args = $self->$orig(@args);
    if ($args->{producer}) {
        $args->{msg_factory} = delete $args->{producer};
    }
    return $args;
};

=head1 METHODS

=cut

sub _build_preorders_for_export {
    my $self = shift;

    return $self->schema
                ->resultset('Public::PreOrder')
                ->with_items_to_export;
}

=over 4

=item B<invoke>

Script entry point

=back

=cut

sub invoke {
    my ($self) = @_;

    $self->log_info('Informing website of preorders with available stock');

    while (my $preorder = $self->preorders_for_export->next ){

        $self->log_debug('Preorder ' . $preorder->id);

        if($self->dryrun){
            say '    Would export preorder: ' . $preorder->id;
            $self->update_item_and_preorder_status($preorder);
            next;
        }

        # Attempt the database status updates first to ensure we can
        # consistently update locally before attempting to send the
        # message. Failure of either operation rolls back the local
        # updates
        try {
            $self->schema->txn_do(
                sub { my $items = $self->update_item_and_preorder_status($preorder);
                      if ( $items ) {
                          $self->send_preorder_message($preorder, $items);
                      }
                      else {
                          die 'No items to update';
                      }
                }
            );
        } catch {
            my $msg = 'Export aborted for Preorder '
                      . $preorder->id
                      . ': '
                      . $_;

            $self->log_error($msg);
            die $msg;
        };
    }

    $self->log_info('Inform Complete');

    return 0;
}

=over 4

=item B<send_preorder_message>

Ascertain queue form config and invoke the named message producer with the
preorder and item information

=back

=cut

sub send_preorder_message {
    my ($self, $preorder, $items) = @_;

    $self->log_debug('Sending message for ' . $preorder->id);

    my $msg_type = 'XT::DC::Messaging::Producer::PreOrder::TriggerWebsiteOrder';

    # the producer knows whether or not to actually send the message
    my $data = {
        preorder => $preorder,
        items    => $items,
    };

    $self->msg_factory->transform_and_send( $msg_type, $data, );

    return 1;
}

=over 4

=item B<update_item_and_preorder_status>

Loop through all exportable preorder items and set the item status to
'exported'. Ascertain whether this completes the preorder and set the overall
preorder status to either 'exported' or 'part-exported' accordingly. Return a
list of exportable items which have been successfully updated to pass to the
message producer.

=back

=cut

sub update_item_and_preorder_status {
    my ($self, $preorder) = @_;

    my @updated_items = ();

    # Update preorder item status
    foreach my $item ($preorder->exportable_items->order_by_id->all){

        if($self->dryrun){
            say '        Would export item: ' . $item->id;
            next;
        }

        $self->log_debug('Setting exported status: ' . $item->id);

        $item->update_status($PRE_ORDER_ITEM_STATUS__EXPORTED);

        push @updated_items, $item;
    }

    if($self->dryrun){ return [] }

    # Update preorder status
    if( $preorder->all_items_are_exported ){
        $self->log_debug('All items exported - update preorder status');
        $preorder->update_status($PRE_ORDER_STATUS__EXPORTED);
    }
    elsif( $preorder->some_items_are_exported ){
        $self->log_debug('Some items exported - update preorder status');
        $preorder->update_status($PRE_ORDER_STATUS__PART_EXPORTED);
    }
    else{
        # no items are exported... er...
        $self->log_debug('No items exported - No status changes');
    }

    return \@updated_items;
}

=over 4

=item B<log_error>

Log at error level and print message to screen if script is running in verbose
mode

=back

=cut

sub log_error {
    my ($self, $msg) = @_;
    $self->_log_and_maybe_msg('error', $msg);
}

=over 4

=item B<log_info>

Log at info level and print message to screen if script is running in verbose
mode

=back

=cut

sub log_info {
    my ($self, $msg) = @_;
    $self->_log_and_maybe_msg('info', $msg);
}

=over 4

=item B<log_debug>

Log at debug level and print message to screen if script is running in verbose
mode

=back

=cut

sub log_debug {
    my ($self, $msg) = @_;
    $self->_log_and_maybe_msg('debug', $msg);
}

sub _log_and_maybe_msg {

    my ($self, $log_method, $msg) = @_;

    # Oh dear, we've confused Log4perl
    local $Log::Log4perl::caller_depth += 2;

    my $allowed_methods = { debug => 1,
                            info  => 1,
                            error => 1
                          };

    $log_method = 'info' unless $allowed_methods->{$log_method};

    $self->logger->$log_method($msg);
    if($self->verbose){ say $msg }
}

1;
