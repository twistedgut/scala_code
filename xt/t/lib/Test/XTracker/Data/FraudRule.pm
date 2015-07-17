package Test::XTracker::Data::FraudRule;

use NAP::policy "tt",     'test';

=head1 NAME

Test::XTracker::Data::FraudRule - To do Fraud Rules Related Stuff

=head1 SYNOPSIS

    package Test::Foo;

    __PACKAGE__->create_fraud_rule;

=cut

use Carp;

use Test::XTracker::Data;
use Test::XT::Data;
use Test::XTracker::Mock::PSP;

use XTracker::Constants::FromDB         qw( :customer_category :order_status :shipment_status );


=head1 METHODS

=head2 create_fraud_rule

    $rule_obj   = __PACKAGE__->create_fraud_rule( 'Live' or 'Staging' );       # will create one Rule with 5 Conditions
        or
    $rule_obj   = __PACKAGE__->create_fraud_rule( 'Live' or 'Staging', { how_many => 3 } );
        or
    $rule_obj   = __PACKAGE__->create_fraud_rule( 'Live' or 'Staging', {
        # create 3 Rules each with 2 Conditions both the same
        how_many          => 3,
        conditions_to_use => [
            {
                # use DBIC Objects to specify what Methods & Operators the Conditions should use
                method   => $method_obj,
                operator => $operator_obj,
                value    => 'value to compare',
            },
            {
                # or just specify the Description of the Methods & Conditions to use
                method   => 'Description of Method in fraud.method table',
                operator => '=',
                value    => 'value to compare',
            },
        ],
        # specify any other attributes you wish to set, such as:
        number_of_conditions    => 3,   # to create every Rule with 3 Conditions
    );
        or
    $rule_obj   = __PACKAGE__->create_fraud_rule( 'Live' or 'Staging', [
        # will create 3 Rules, the first with 2 Conditions, the
        # second with 3 conditions and the fourth with 4 conditions
        {
            # specify attributes you wish to set, such as:
            number_of_conditions    => 2,
        },
        {
            # specify attributes you wish to set, such as:
            number_of_conditions    => 3,
        },
        {
            # specify attributes you wish to set, such as:
            number_of_conditions    => 4,
        },
    ] );

Will create either a 'Live' or 'Staging' Rule depending on what is passed as the first parameter. By default
5 Conditions will also be created with every Rule, pass extra arguments as above to change how many and what
Conditions are created.

When a 'Live' Rule is created it will also create a version in the 'fraud.archived_rule' & 'fraud_staging_rule'
tables.

=cut

sub create_fraud_rule {
    my ( $self, $type, $args )  = @_;

    croak "Type of Rule Must be specified, either 'Live' or 'Staging' for '" . __PACKAGE__ . "->create_fraud_rule'"
                        if ( !$type );

    # create one rule by default
    my $how_many    = 1;

    my @to_create;
    if ( ref( $args ) eq 'HASH' ) {
        $how_many   = delete $args->{how_many} // 1;
        @to_create  = ( $args // {} ) x $how_many;
    }
    elsif ( ref( $args ) eq 'ARRAY' ) {
        @to_create  = @{ $args };
    }
    else {
        # this is so there is at least
        # one element in the array
        @to_create  = ( {} );
    }

    my @rules;
    my $change_log;
    foreach my $to_create ( @to_create ) {

        my $framework   = Test::XT::Data->new_with_traits(
            traits => [
                'Test::XT::Data::Channel',
                'Test::XT::Data::FraudChangeLog',
                'Test::XT::Data::FraudRule',
            ],
        );
        $framework->rule_type( $type );

        if ( $framework->is_live_rule ) {
            # if we've been asked to get Live Rules make
            # sure the same Change log is used every time
            $change_log = $framework->fraud_change_log(
                $change_log // $framework->fraud_change_log
            );
        }

        ARGS:
        foreach my $attribute ( keys %{ $to_create } ) {
            next ARGS       if ( !$framework->can( $attribute ) );
            $framework->$attribute( $to_create->{ $attribute } );
        }

        if ( $to_create->{conditions_to_use} ) {
            # to make things predicatable set the processing
            # cost of each Condition in sequential order of
            # it appearing in the 'conditions_to_use' array
            my $cost    = 1;
            foreach my $condition ( @{ $to_create->{conditions_to_use} } ) {
                $condition->{processing_cost}   = $cost;
                $cost++;
            }
        }

        push @rules, $framework->fraud_rule;
    }

    return $rules[0]    if ( $how_many == 1 );
    return ( wantarray ? @rules : \@rules );
}

=head2 create_order

    $order_obj  = __PACKAGE__->create_order( $optional_channel_object );

Will create an Order which is set-up with the Fraud Rules Engine in mind to honor
a set of Conditions that can be used when Creating Fraud Rules. These Conditions
can be found in the method 'test_conditions'.

=cut

sub create_order {
    my ( $self, $channel )  = @_;

    my $schema  = Test::XTracker::Data->get_schema;
    my $dbh     = $schema->storage->dbh;

    my $data    = Test::XT::Data->new_with_traits(
        traits  => [
            'Test::XT::Data::Channel',
            'Test::XT::Data::Customer',
            'Test::XT::Data::Order',
        ],
    );

    $data->channel( $channel )      if ( $channel );

    # use a Unique Email Address so the Customer won't
    # match any other Customers on any other Channel
    $data->customer->update( {
        email       => Test::XTracker::Data->create_unmatchable_customer_email( $dbh ),
        category_id => $CUSTOMER_CATEGORY__NONE,
    } );

    my $order   = $data->new_order(
        channel  => $data->channel,
        customer => $data->customer,
        tenders  => [ { type => 'card_debit', value => 1100 } ],
    )->{order_object};

    my $shipment    = $order->get_standard_class_shipment;

    my $next_preauth = Test::XTracker::Data->get_next_preauth();
    Test::XTracker::Data->create_payment_for_order( $order, {
        psp_ref     => $next_preauth,
        preauth_ref => $next_preauth,
    } );

    my $inv_addr    = Test::XTracker::Data->create_order_address_in( 'current_dc', { country => 'Brazil' } );
    my $ship_addr   = Test::XTracker::Data->create_order_address_in( 'current_dc', { country => 'South Africa' } );
    $order->update( { invoice_address_id => $inv_addr->id } );
    $shipment->update( { shipment_address_id => $ship_addr->id } );
    $order->orders_rule_outcome->delete         if ( $order->orders_rule_outcome );

    $self->reset_order_statuses( $order );

    return $order->discard_changes;
}

=head2 reset_order_statuses

    __PACKAGE__->reset_order_statuses;

Will reset the Order Status and Shipment Status to be 'Accepted' and 'Processing' respectively and will
also remove any Status Log records for those records.

=cut

sub reset_order_statuses {
    my ( $self, $order )    = @_;

    my $shipment    = $order->discard_changes->get_standard_class_shipment;

    $order->order_status_logs->delete;
    $order->update( { order_status_id => $ORDER_STATUS__ACCEPTED } );
    $shipment->shipment_status_logs->delete;
    $shipment->update( { shipment_status_id => $SHIPMENT_STATUS__PROCESSING } );

    return;
}

=head2 test_conditions

    $hash_ref   = __PACKAGE__->test_conditions;

A list of Conditions that can be used by 'create_fraud_rule' to create Rules with.

The key to the Hash describes what the Condition will be TRUE for, such as:

    * "Is Customer's First Order - TRUE"
    * "Is Customer's First Order - FALSE"
    * "Customer is an EIP - FALSE"
    * "Customer is an EIP - TRUE"
    * "Number of Orders in last 7 days - > 3"
    * "Number of Orders in last 7 days - <= 3"
    etc...

These conditions are meant to go with the Order that will be created using the 'create_order' method
but they can be used for any Order you wish it's just up to you to make sure they will each Pass when
you apply them to your own Order.

Please look in the Code to see a complete list of the Conditions available.

=cut

sub test_conditions {
    my $self    = shift;

    return {
        "Is Customer's First Order - TRUE" => {
            method  => "Is Customer's First Order",
            operator=> 'Is',
            value   => 1,
        },
        "Is Customer's Second Order - TRUE" => {
            method  => "Is Customer's Second Order",
            operator=> 'Is',
            value   => 1,
        },
        "Is Customer's Third Order - TRUE" => {
            method  => "Is Customer's Third Order",
            operator=> 'Is',
            value   => 1,
        },
        "Customer is an EIP - FALSE" => {
            method  => 'Customer is an EIP',
            operator=> 'Is',
            value   => 0,
        },
        "Number of Orders in last 7 days - <= 3" => {
            method  => 'Number of Orders in last 7 days',
            operator=> '<=',
            value   => 3,
        },
        "Is In The Hotlist - TRUE" => {
            method  => 'Is In The Hotlist',
            operator=> 'Is',
            value   => 1,
        },
        "Shipping Address Equal To Billing Address - TRUE" => {
            method  => 'Shipping Address Equal To Billing Address',
            operator=> 'Is',
            value   => 1,
        },
        "Shipping Address Country - Is Brazil" => {
            method  => 'Shipping Address Country',
            operator=> '=',
            value   => 'Brazil',
        },
        "Is Customer's First Order - FALSE" => {
            method  => "Is Customer's First Order",
            operator=> 'Is',
            value   => 0,
        },
        "Is Customer's Second Order - FALSE" => {
            method  => "Is Customer's Second Order",
            operator=> 'Is',
            value   => 0,
        },
        "Is Customer's Third Order - FALSE" => {
            method  => "Is Customer's Third Order",
            operator=> 'Is',
            value   => 0,
        },
        "Customer is an EIP - TRUE" => {
            method  => 'Customer is an EIP',
            operator=> 'Is',
            value   => 1,
        },
        "Number of Orders in last 7 days - > 3" => {
            method  => 'Number of Orders in last 7 days',
            operator=> '>',
            value   => 3,
        },
        "Is In The Hotlist - FALSE" => {
            method  => 'Is In The Hotlist',
            operator=> 'Is',
            value   => 0,
        },
        "Shipping Address Equal To Billing Address - FALSE" => {
            method  => 'Shipping Address Equal To Billing Address',
            operator=> 'Is',
            value   => 0,
        },
        "Shipping Address Country - Is Not Brazil" => {
            method  => 'Shipping Address Country',
            operator=> '!=',
            value   => 'Brazil',
        },
        "Disabled - Is Customer's First Order - TRUE" => {
            method  => "Is Customer's First Order",
            operator=> 'Is',
            value   => 1,
            enabled => 0,
        },
        "Disabled - Is Customer's Second Order - TRUE" => {
            method  => "Is Customer's Second Order",
            operator=> 'Is',
            value   => 1,
            enabled => 0,
        },
        "Disabled - Is Customer's Third Order - TRUE" => {
            method  => "Is Customer's Third Order",
            operator=> 'Is',
            value   => 1,
            enabled => 0,
        },
        "Disabled - Customer is an EIP - TRUE" => {
            method  => 'Customer is an EIP',
            operator=> 'Is',
            value   => 1,
            enabled => 0,
        },
    };
}

=head2 delete_fraud_rules

    __PACKAGE__->delete_fraud_rules;

This will delete All Staging and Live Rules & Conditions.

=cut

sub delete_fraud_rules {
    my $self    = shift;

    my $schema  = Test::XTracker::Data->get_schema;

    $schema->resultset('Fraud::StagingCondition')->delete;
    $schema->resultset('Fraud::StagingRule')->delete;
    $schema->resultset('Fraud::LiveCondition')->delete;
    $schema->resultset('Fraud::LiveRule')->delete;

    return;
}

=head2 create_live_rule_set

    $hash_ref = __PACKAGE__->create_rule_set( $rules, $channel );

Create a set of Live Rules for the given Sales Channel, $rules should
contain the same arguments as required for the 'create_fraud_rule', method
but if you just want a Rule with one condition just pass it's details in a
HashRef to the 'condition' key and you won't need the 'conditions_to_use'
key.

It will return a HashRef of the different Rule Classes with
an Array of Rules in Rule Sequence order:

    {
        Live     => [ $rule_objects, ... ],
        Staging  => [ $rule_objects, ... ],
        Archived => [ $rule_objects, ... ]
    }

=cut

sub create_live_rule_set {
    my ( $self, $rules, $channel )  = @_;

    my @live_rules,
    my @staging_rules;
    my @archived_rules;

    foreach my $rule ( @{ $rules } ) {
        $rule->{channel}            = $channel;
        $rule->{conditions_to_use}  = [ delete $rule->{condition} ]     if ( $rule->{condition} );

        my $live_rule       = $self->create_fraud_rule( 'Live', $rule );
        my $staging_rule    = $live_rule->staging_rules->first;
        my $archived_rule   = $live_rule->archived_rule;

        push @live_rules, $live_rule;
        push @staging_rules, $staging_rule;
        push @archived_rules, $archived_rule;
    }

    my %rule_set    = (
        Live    => [ sort { $a->rule_sequence <=> $b->rule_sequence } @live_rules ],
        Staging => [ sort { $a->rule_sequence <=> $b->rule_sequence } @staging_rules ],
        Archived=> [ sort { $a->rule_sequence <=> $b->rule_sequence } @archived_rules ],
    );

    return \%rule_set;
}

=head2 create_live_rule_to_always_accept

    __PACKAGE__->create_live_rule_to_always_accept;

Will create a Live Rule that will always Accept an Order. This
will wipe out all existing Rules.

=cut

sub create_live_rule_to_always_accept {
    my $self    = shift;

    $self->delete_fraud_rules;

    $self->create_fraud_rule( 'Live', {
        how_many    => 1,
        channel     => undef,
        rule_action_status_id => $ORDER_STATUS__ACCEPTED,
        conditions_to_use => [
            {
                method   => 'Order Total Value',
                operator => '>=',
                value    => 0.00
            },
        ],
    } );

    return;
}

=head2 switch_all_channels_on

    __PACKAGE__->switch_all_channels_on;

Switches the use of the Fraud Rule Engine to 'On' for all Sales Channels.

=cut

sub switch_all_channels_on {
    my $self    = shift;

    $self->_switch_all_channels_to('On');
    return;
}

=head2 switch_all_channels_off

    __PACKAGE__->switch_all_channels_off;

Switches the use of the Fraud Rule Engine to 'Off' for all Sales Channels.

=cut

sub switch_all_channels_off {
    my $self    = shift;

    $self->_switch_all_channels_to('Off');
    return;
}

=head2 switch_all_channels_to_parallel

    __PACKAGE__->switch_all_channels_to_parallel;

Switches the use of the Fraud Rule Engine to 'Parallel' for all Sales Channels.

=cut

sub switch_all_channels_to_parallel {
    my $self    = shift;

    $self->_switch_all_channels_to('Parallel');
    return;
}

# helper that just switches the Fraud
# Channel Switch to whatever is passed in.
sub _switch_all_channels_to {
    my ( $self, $state )    = @_;

    my $schema  = Test::XTracker::Data->get_schema;
    my @channels= $schema->resultset('Public::Channel')->all;

    Test::XTracker::Data->remove_config_group( 'Fraud Rules' );
    foreach my $channel ( @channels ) {
        Test::XTracker::Data->create_config_group( 'Fraud Rules', {
            channel     => $channel,
            settings    => [
                { setting => 'Engine', value => $state },
            ],
        } );
    }

    return;
}

=head2 split_live_and_archived_id_sequences

    __PACKAGE__->split_live_and_archived_id_sequences();

Because we use Blank DBs most of the Time the Id of the Live Rule and
Archived Rule tables will be the same.

If you need them to be different to make sure in your tests you don't
have coincidences where they're both the same and so find the correct
record by accident then call this method.

=cut

sub split_live_and_archived_id_sequences {
    my $self = shift;

    # set the Archived to be 1000 away from the Live
    my $next_urn = Test::XTracker::Data->bump_sequence( 'fraud.live_rule' );
    Test::XTracker::Data->bump_sequence( 'fraud.archived_rule', 'id', ( $next_urn + 1000 ) );

    return;
}


=head2 create_fraud_list

    my $list = Test::XTracker::Data::FraudRule->create_fraud_list( 'staging', {
        name        => 'Name for List',
        description => 'A description for the list',
        list_items  => [ qw/
            item_1
            item_2
            item_3
        / ],
    } );

Creates a list for the specified rule set (staging or live).

Required parameters:

    ruleset - must be passed as the first parameter and must be live or staging
    rule definition - a hashref containing a definition of the required rule
                      must be passed as the second parameter. The hashref must
                      containg the following:

        * name - a unique name for the list
        * description - a description for the list
        * items - an array ref containing a list of item values

=cut

sub create_fraud_list {
    my ($self, $rule_set, $args ) = @_;

    die "You must specify a rule set" unless $rule_set;
    die "Rule set must be archived, live or staging"
        unless $rule_set =~ /\A(live|staging|archived)\z/;

    unless ( $args && ref $args eq 'HASH' ) {
        die "You must pass a hashref with list details";
    }

    foreach my $required ( qw/ list_items name description / ) {
        die "Required key $required not in hashref"
            unless defined $args->{$required};
    }

    my $list_items = delete $args->{list_items};

    my $schema = Test::XTracker::Data->get_schema;
    $rule_set = 'Fraud::'.ucfirst(lc($rule_set)).'List';
    my $list = $schema->resultset($rule_set)->create($args);

    foreach my $list_item ( @$list_items ) {
        $list->create_related('list_items', { value => $list_item } );
    }

    return $list;
}

1;
