package XT::Domain::Fraud::RemoteDCQuery;

use NAP::policy "tt", 'class';
with qw/XTracker::Role::WithAMQMessageFactory/;

use JSON::XS;
use Data::UUID;
use Log::Log4perl;
use XT::Net::Seaview::Client;
use XTracker::Constants qw/$APPLICATION_OPERATOR_ID/;
use XTracker::Constants::FromDB qw/:flag :order_status :shipment_status/;
use XTracker::Config::Local qw/config_var/;
use XTracker::Database::Order qw/get_order_info/;
use XTracker::Database::Shipment qw/get_order_shipment_info/;
use XTracker::Logfile qw/xt_logger/;
use XTracker::Order::Utils::StatusChange;

=head1 NAME

XT::Domain::Fraud::RemoteDCQuery

=head1 DESCRIPTION

Ask and answer questions relating to a customer's relationship with other DCs

=head1 CLASS DATA

=head2 %questions

Holds the allowed questions and mapping to action methods

=cut

my %questions
  = ( 'CustomerHasGenuineOrderHistory?'
        => { question => 'has_genuine_order_history',
             positive_action => 'release_order_from_credit_hold',
             negative_action => 'log_it',
             bogus_action => 'place_order_on_credit_hold',
           }
    );

=head1 ATTRIBUTES

=head2 schema

=cut

has schema => (
    is          => 'ro',
    isa         => 'DBIx::Class::Schema|XTracker::Schema|XT::DC::Messaging::Model::Schema',
    required    => 1,
);

=head2 schema

=cut

has seaview => (
    is       => 'ro',
    isa      => 'XT::Net::Seaview::Client',
    required => 1,
    lazy     => 1,
    default  => sub {XT::Net::Seaview::Client->new({schema => $_[0]->schema})},
);

=head2 log

=cut

has log => (
    is       => 'ro',
    isa      => 'Log::Log4perl::Logger',
    required => 1,
    lazy     => 1,
    default  => sub { xt_logger },
);

=head2 query_enabled

=cut

has query_enabled => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
    lazy     => 1,
    default  => sub { config_var('DCQuery','query_enabled') },
);

=head1 METHODS

=head2 ask

=cut

sub ask {
    my ($self, $q, $order_id) = @_;

    # Find the order
    my $order = $self->schema->resultset('Public::Orders')->find($order_id);

    if(defined $order){
        if(defined $questions{$q}){
            # Create a query reference
            my $qid = Data::UUID->new->create_str();
            $order->create_related( 'remote_dc_query',
                                    { id => $qid, query_type => $q });

            my $rq
              = $self->schema->resultset('Public::RemoteDcQuery')->find($qid);

            # Send the query
            $self->msg_factory->transform_and_send(
                'XT::DC::Messaging::Producer::DCQuery::FraudQuery',
                { query_id => $rq->id,
                  account_urn => $order->customer->account_urn,
                  query => $rq->query_type,
                });
        }
    }

    return 1;
}

=head2 answer

=cut

sub answer {
    my ($self, $message) = @_;

    # Send the response message
    {
        my $method = $self->can($questions{$message->{query}}->{'question'});

        if(ref $method eq 'CODE'){
            $self->msg_factory->transform_and_send(
                'XT::DC::Messaging::Producer::DCQuery::FraudAnswer',
                { query_id => $message->{query_id},
                  answer => $self->$method($message),
                });
        }
        else {
            # No executable method found
        }
    }

    return 1;
}

=head2 positive_action

=cut

sub positive_action {
    my ($self, $query_type, $order_id) = @_;

    {
        my $method = $self->can($questions{$query_type}->{'positive_action'});
        if(ref $method eq 'CODE'){
            $self->$method($query_type, $order_id),
        }
        else {
            # No executable method found
        }
    }

    return 1;
}

=head2 negative_action

=cut

sub negative_action {
    my ($self, $query_type, $order_id) = @_;

    {
        my $method = $self->can($questions{$query_type}->{'negative_action'});
        if(ref $method eq 'CODE'){
            $self->$method($query_type, $order_id),
        }
        else {
            # No executable method found
        }
    }

    return 1;
}

=head2 has_genuine_order_history

Check the local DC history and return true if the customer has made genuine
orders in the past

=cut

sub has_genuine_order_history {
    my ($self, $message) = @_;

    # Verdict is false by default
    my $verdict = JSON::XS::false;

    # Seaview query for customer id
    my $account = undef;
    try{
        $account = $self->seaview->account($message->{account_urn});
    }
    catch{
        $self->log->warn($_);
    };

    if(defined $account->origin_id){
        # Get the customer
        my $customer
          = $self->schema->resultset('Public::Customer')
                         ->search({is_customer_number => $account->origin_id})
                         ->first;

        if(defined $customer){
            if(   $customer->is_trusted
               && $customer->has_genuine_order_history){
               $verdict = JSON::XS::true;
            }
            else {
                # stays false
            }
        }
        else {
            # No customer found - no order history - stays false
        }
    }
    else {
        # No account found - no order history - stays false
    }

    return $verdict;
}

=head2 release_order_from_credit_hold

=cut

sub release_order_from_credit_hold {
    my ($self, $query_type, $order_id) = @_;

    my $dbh = $self->schema->storage->dbh;
    my $status_change
      = XTracker::Order::Utils::StatusChange->new({schema => $self->schema});

    $self->log->debug("Order $order_id released from credit hold as $query_type response was positive");

    # Find the order
    my $order = $self->schema->resultset('Public::Orders')->find($order_id);
    my $order_ref = get_order_info($dbh, $order->id);
    my $shipments_ref = get_order_shipment_info($dbh, $order_id);

    # Is the order still on credit hold?
    if($order->is_on_credit_hold){
        # If so release it
        $status_change->change_order_status($order->id,
                                            $ORDER_STATUS__ACCEPTED,
                                            $APPLICATION_OPERATOR_ID);

        $status_change->accept_order($order_ref,
                                     $shipments_ref,
                                     $order->id,
                                     $APPLICATION_OPERATOR_ID);

        # Flag the order as released via remote query
        $order->add_flag_once($FLAG__RELEASED_VIA_REMOTE_DC_QUERY);
    }
    else{
        # Order already released
    }
    return 1;
}

=head2 place_order_on_credit_hold

=cut

sub place_order_on_credit_hold {
    my ($self, $query_type, $order_id) = @_;

    my $dbh = $self->schema->storage->dbh;
    my $status_change
      = XTracker::Order::Utils::StatusChange->new({schema => $self->schema});

    $self->log->debug("Order $order_id placed on credit hold as $query_type response bogus");

    # Find the order
    my $order = $self->schema->resultset('Public::Orders')->find($order_id);
    my $order_ref = get_order_info($dbh, $order->id);
    my $shipments_ref = get_order_shipment_info($dbh, $order_id);

    # If the order is not on credit hold then hold it
    if(!$order->is_on_credit_hold){
        $status_change->change_order_status($order->id,
                                            $ORDER_STATUS__CREDIT_HOLD,
                                            $APPLICATION_OPERATOR_ID);

        $status_change->update_shipments_status($shipments_ref,
                                                $SHIPMENT_STATUS__FINANCE_HOLD,
                                                $APPLICATION_OPERATOR_ID);

    }
    else{
        # Order is already on hold
    }

    # Flag the order as released via remote query
    $order->add_flag_once($FLAG__REMOTE_DC_QUERY_POTENTIAL_FRAUD);

    return 1;
}

=head2 log_it

=cut

sub log_it {
    my ($self, $query_type, $order_id) = @_;

    $self->log->info("Order $order_id staying on credit hold as $query_type response was negative");

    return 1;
}
