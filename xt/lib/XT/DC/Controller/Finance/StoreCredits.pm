package XT::DC::Controller::Finance::StoreCredits;
# vim: set ts=4 sw=4 sts=4:

use Moose;

BEGIN { extends 'Catalyst::Controller' };

use XTracker::Constants::FromDB qw(
    :customer_category
    :renumeration_class
    :renumeration_status
    :renumeration_type
);
use XTracker::Config::Local qw/ can_deny_store_credit_for_channel /;
use XTracker::Database;
use XTracker::Database::Customer;
use XTracker::Database::Currency    qw( get_currencies_from_config );
use Data::Dump qw(pp);
use DateTime::Format::ISO8601;
use JSON qw/decode_json/;
use XTracker::Config::Local ();
use Scalar::Util qw(looks_like_number);
with 'XTracker::Role::WithCreditClient';

sub root : Chained('/') PathPart('Finance/StoreCredits') CaptureArgs(0) {
    my ($self, $c) = @_;

    $c->check_access('Finance', 'Store Credits');
}

sub search : Chained('root') PathPart('') Args(0) ActionClass('REST') {
    my ($self, $c) = @_;

    $c->stash(
        sidenav => [
            { None => [{ 'title' => 'Create Store Credit', 'url' => "/Finance/StoreCredits/Create"}] }
        ]
    );
}

sub search_GET { }

sub search_POST {
    my ($self, $c) = @_;

    # TODO: Channel id form field.
    my @customers = eval {
        $c->model('DB::Public::Customer')
          ->search_by_pws_customer_nr( $c->req->param('customer_nr') )
          ->all
    };

    if (@customers == 1) {
        # Go directly to the results page.
        $c->res->redirect( $c->uri_for(
            $self->action_for('view_store_credit'), [$customers[0]->id]
        ) );
    }

    my $credits = { };

    # TODO: This ideally would want to sent multiple messages before awaiting
    # reply, or to send all customer ids in a single message.
    foreach my $cust (@customers) {

        $credits->{$cust->id} = $self->_retrieve_store_credit_history($c, $cust);
    }

    if ( !@customers ) {
        $c->feedback_warn( "Couldn't find any Customers or Web-Site not responding" );
    }
    $c->stash( customers => \@customers, credits => $credits );
}

sub customer : Chained('root') CaptureArgs(1) PathPart('') {
    my ($self, $c, $id) = @_;

    my $cust = eval { $c->model('DB::Public::Customer')->find($id) };

    unless ($cust) {
        $c->res->redirect( $c->uri_for( $self->action_for('search') ) );
        $c->detach;
    }

    $c->stash(
        customer => $cust,
        sales_channel => $cust->channel->name,
        config_section => $cust->channel->business->config_section,
        sidenav => [ { None => [
            { 'title' => 'Back', 'url' => $c->uri_for( $self->action_for('search'), [] ) },
            { 'title' => 'Edit', 'url' => $c->uri_for( $self->action_for('edit_store_credit'), [$cust->id] ) },
        ] } ]
    );
}

sub fetch_store_credit : Chained('customer') CaptureArgs(0) PathPart('') {
    my ($self, $c) = @_;

    # This flash storing (from create or edit) doesn't actually seem to work. Arse.
    my $credit = $self->_retrieve_store_credit_history($c, $c->stash->{customer});
    if (!$credit) {
        $c->res->redirect( $c->uri_for( $self->action_for('create_store_credit'), [$c->stash->{customer}->id] ) );
        $c->detach;
    }
    $c->stash( credit => $credit );
}

sub view_store_credit : Chained('fetch_store_credit') Args(0) PathPart('') { }

sub edit_store_credit : Chained('customer') Args(0) PathPart('edit') ActionClass('REST') {
    my ($self, $c) = @_;
}

sub edit_store_credit_GET {
    my ($self, $c) = @_;

    # We need to get the balance and currency, so go via fetch_store_credit
    $c->forward('fetch_store_credit');

    my $cust = $c->stash->{customer};

    $c->stash(
        subsubsection => 'Edit',
        sidenav => [ { None => [
            { 'title' => 'Back', 'url' => $c->uri_for( $self->action_for('view_store_credit'), [$cust->id] ) },
        ] } ],
        js      => [ '/javascript/finance/store_credit.js' ],
    );

}

sub edit_store_credit_POST {
    my ($self, $c) = @_;

    my $cust = $c->stash->{customer};

    my $value = $self->_validate_value($c);
    if ( !defined $value ) {
        return;
    }

    my ($status,$balance) = $self->customer_credit_client
        ->add_store_credit(
            $cust->channel->web_name,
            $cust->pws_customer_id,
            $c->req->body_params->{currency},
            $value,
            $c->session->{operator_name},
            $c->req->body_params->{notes},
        );

    $c->res->redirect( $c->uri_for( $self->action_for('view_store_credit'), [$cust->id] ) );

    if ($status ne 'ok') {
        require Data::Dumper;
        $c->feedback_warn("Error response from website: ".Data::Dumper::Dumper($balance));
        return;
    }
}

# This one gives the option to enter customer credit and has a channel drop down
sub full_create_store_credit : Chained('root') Args(0) PathPart('Create') ActionClass('REST') {
    my ($self, $c) = @_;
    $c->stash( template => 'finance/storecredits/create_store_credit.tt' );
}

sub full_create_store_credit_GET {
    my ($self, $c) = @_;

    my $schema = $c->model('DB')->schema;

    my @channels = ();
    my @chs = $c->model('DB::Public::Channel')->all;
    foreach my $ch (@chs) {
        my $channel_config = {
            name => $ch->name,
            id   => $ch->id,
        };
        # Do we allow store credit for this channel?
        $channel_config->{deny_store_credit} = can_deny_store_credit_for_channel( $schema, $ch->id );

        push @channels, $channel_config;
    }

    $c->stash( channels => \@channels );

    $self->create_store_credit_GET($c);
}

sub full_create_store_credit_POST {
    my ($self, $c) = @_;

    my $customer_rs = $c->model('DB::Public::Customer');
    my $customer_nr = scalar $c->req->param('customer_nr');
    my (@customers) = eval {
        $customer_rs->search_by_pws_customer_nr( $customer_nr )
                    ->search({ channel_id => scalar $c->req->param('channel') })
                    ->all
    };

    # If the customer doesn't exist in XT but does on the website, create it
    unless ( @customers ) {
        my $customer_ref = $self->get_customer( $c );
        if ( $customer_ref ) {
            push @customers, $customer_rs->create({
                is_customer_number => $customer_nr,
                first_name         => $customer_ref->{first_name},
                last_name          => $customer_ref->{last_name},
                email              => $customer_ref->{email},
                category_id        => $CUSTOMER_CATEGORY__NONE,
                created            => DateTime->now,
                modified           => DateTime->now,
                channel_id         => $c->req->param('channel'),
            });
        }
        else {
            $c->feedback_warn( "Customer $customer_nr not found on website" );
            $c->stash(
                channels => [ $c->model('DB::Public::Channel')->all ],
            );
            # For some reason the feedback_warn's flash entry doesn't survive
            # the redirect here (maybe due to REST?), so instead of
            # redirecting we're calling create_store_credit_GET - DJ
            $self->create_store_credit_GET($c);
            $c->detach();
        }
    }

    $c->stash( customer => $customers[0] );
    $self->create_store_credit_POST($c);
}

# This sql call reads from the website db. Someone please make this a message
# once we can get some time from the java guys...!  - DJ
sub get_customer {
    my ( $self, $c ) = @_;
    my $channel = $c->model('DB::Public::Channel')->find( $c->req->param('channel') );

    my $dbh_web = XTracker::Database::get_database_handle({
        name => 'Web_Live_' . $channel->business->config_section,
        type => 'transaction',
    });

    my $customer_ref = XTracker::Database::Customer::get_customer_from_pws(
        $dbh_web, $c->req->body_params->{customer_nr}
    );

    $dbh_web->commit();
    $dbh_web->disconnect();

    return $customer_ref;
}

# This one is from a link for an existing customer
sub create_store_credit : Chained('customer') Args(0) PathPart('create') ActionClass('REST') {
    my ($self, $c) = @_;
}

sub create_store_credit_GET {
    my ($self, $c) = @_;

    $c->stash(
        sidenav => [ { None => [
            { 'title' => 'Back', 'url' => $c->uri_for( $self->action_for('search'), [] ) },
        ] } ],
        currency => get_currencies_from_config( $c->model('DB')->schema ),
        js      => [ '/javascript/finance/store_credit.js' ],
    );
}

sub create_store_credit_POST {
    my ($self, $c) = @_;

    my $cust = $c->stash->{customer};
    my $currency = $c->model('DB::Public::Currency')->find( scalar $c->req->param('currency') );


    my $value = $self->_validate_value($c);
    if ( !defined $value ) {
        return;
    }

    my ($status,$balance) = $self->customer_credit_client
        ->add_store_credit(
            $cust->channel->web_name,
            $cust->pws_customer_id,
            $currency->currency,
            $value,
            $c->session->{operator_name},
            $c->req->body_params->{notes},
        );

    if ($status ne 'ok') {
        $c->res->redirect( $c->uri_for( $self->action_for('view_store_credit'), [$cust->id] ) );
        # Due to feedback_warn not surviving redirects the user will never see
        # this error message :(
        require Data::Dumper;
        $c->feedback_warn("Error response from website: ".Data::Dumper::Dumper($balance));
        return;
    }

    $c->res->redirect( $c->uri_for( $self->action_for('view_store_credit'), [$cust->id] ) );
}

# This one gives the option to convert customer credit to a card refund
sub convert_to_refund : Chained('fetch_store_credit') Args(0) PathPart('ConvertToRefund') ActionClass('REST') {
    my ($self, $c) = @_;
    $c->stash( template => 'finance/storecredits/view_store_credit.tt' );
}

sub convert_to_refund_POST {
    my ($self, $c) = @_;

    my $cust    = $c->stash->{customer};

    # only convert if credit value > 0
    if ( $c->stash->{credit}{balance} > 0 ) {

        # get last store credit renumeration
        # if there is one
        # NOTE: The value doesn't have to equal the current Store Credit Balance
        my $orig_renum  = eval {
                                return $cust->orders
                                       ->related_resultset('link_orders__shipments')
                                         ->related_resultset('shipment')
                                           ->related_resultset('renumerations')
                                             ->search(
                                                {
                                                    renumeration_type_id    => $RENUMERATION_TYPE__STORE_CREDIT,
                                                    renumeration_status_id  => $RENUMERATION_STATUS__COMPLETED,
                                                },
                                                {
                                                    order_by=> 'renumerations.id DESC',
                                                    rows    => 1,
                                                }
                                              )->first;
                          };

        if ( defined $orig_renum ) {
            my $credit_value    = $c->stash->{credit}{balance};
            my $decrement_value = $credit_value * -1;

            my $schema  = $c->model('DB::Public::Renumeration')->result_source->schema;
            my $txn = $schema->txn_scope_guard;

            eval {
                # create Card Refund for value of Current Store Credit
                my $new_renum   = $c->model('DB::Public::Renumeration')->create( {
                                        shipment_id             => $orig_renum->shipment_id,
                                        invoice_nr              => '',
                                        renumeration_type_id    => $RENUMERATION_TYPE__CARD_REFUND,
                                        renumeration_class_id   => $RENUMERATION_CLASS__GRATUITY,
                                        renumeration_status_id  => $RENUMERATION_STATUS__AWAITING_ACTION,
                                        misc_refund             => $credit_value,
                                        currency_id             => $c->stash->{credit}{currency}->id,
                                    } );
                $new_renum->create_related( 'renumeration_status_logs', {
                                                    renumeration_status_id  => $RENUMERATION_STATUS__AWAITING_ACTION,
                                                    operator_id             => $c->session->{operator_id},
                                                } );

                # update previous renumeration to be cancelled and log the change
                $orig_renum->update( { renumeration_status_id => $RENUMERATION_STATUS__CANCELLED } );
                $orig_renum->create_related( 'renumeration_status_logs', {
                                                    renumeration_status_id  => $RENUMERATION_STATUS__CANCELLED,
                                                    operator_id             => $c->session->{operator_id},
                                                } );

                # send message to web-site to zero out Store Credit
                my ($status,$balance) = $self->customer_credit_client
                    ->add_store_credit(
                        $cust->channel->web_name,
                        $cust->pws_customer_id,
                        $c->stash->{credit}{currency}->currency,
                        $decrement_value,
                        $c->session->{operator_name},
                        'Converted to Refund',
                    );

                if ($status eq 'ok') {
                    $c->res->redirect( $c->uri_for( $self->action_for('view_store_credit'), [$cust->id] ) );
                }
                else {
                    require Data::Dumper;
                    die "Error response from website: ".Data::Dumper::Dumper($balance);
                }

                $c->feedback_success("Credit successfully converted");
                $txn->commit();
            };
            if ( my $err = $@ ) {
                $c->feedback_warn("Problem Converting to Refund: $err");
            }
        }
        else {
            # couldn't find a Store Credit renumeration
            # so can't convert credit
            $c->feedback_warn("Could not find credit order to assign refund to");
        }
    }
    else {
        $c->feedback_warn("No Store Credit to Convert");
    }

    return;
}

sub _retrieve_store_credit_history {
    my ($self, $c, $customer) = @_;

    my $ops_rs = $c->model('DB::Public::Operator');
    my $order_rs = $c->model('DB::Public::Orders')->search({ channel_id => $customer->channel_id });
    my $currency_rs = $c->model('DB::Public::Currency');

    my $ret = {
        customer => $customer,
        logs => [],
    };

    my $client =  $self->customer_credit_client;

    my ($status,$credits) = $client->get_store_credit_and_log(
        $customer->channel->web_name,
        $customer->pws_customer_id,
    );

    if ($status eq 'error') {
        require Data::Dumper;
        $c->feedback_error("Unable to query website for store credit information: ".Data::Dumper::Dumper($credits));
        return;
    }

    # No store credit record for this customer.
    return unless $credits;

    my $currency = $currency_rs->find_by_name(
        $credits->[0]{'currencyCode'} //'UNK'
    ) // $currency_rs->find_by_name( 'UNK' );

    $ret->{currency} = $currency;
    my $balance = $ret->{balance} = $credits->[0]{credit};

    my $deltas = $credits->[0]{log};

    my %actions = (
        'REFUNDED' => 'Refund',
        'ORDERED' => 'Order',
        'ORDER_PAYMENT' => 'Order',
    );

    for my $l ( @{ $deltas } ) {
        my $created_by = delete $l->{createdBy};

        $l->{type} = $actions{$l->{type}} || $l->{type};
        $l->{created_by} = $ops_rs->find($1) if $created_by =~ /^xt-([0-9]+)$/;
        $l->{created_by} ||= $created_by;

        $l->{date} = DateTime::Format::ISO8601->parse_datetime( $l->{date}{iso8601} );

        if (my $o_nr = delete $l->{orderNumber}) {
            $l->{order} = $order_rs->search({ order_nr => $o_nr }, { rows => 1 })->next;
            if ( defined $l->{order} ) {
                $l->{type} .= " (O.Nr: $o_nr)";
            }
        }

        $l->{balance} = $balance;
        $balance -= $l->{delta};

        push @{$ret->{logs}}, $l;
    }

    return $ret;
}


sub _validate_value {
    my ($self, $c ) = @_;


    #validation for value to be numeric
    my $value = $c->req->body_params->{value};
    #strip commas and spaces
    $value =~ s/[, ]//g if $value;

    if(!looks_like_number($value)) {
        $c->feedback_warn("Value is not Numeric. Please input Numeric value.");
        return;
    }

    return $value;
}
1;
