package XT::Order::Role::Parser::Common::OrderData;
use NAP::policy "tt", 'role';

use XT::Data::Types;
use DateTime::Format::Strptime;
use Data::Dump qw/pp/;
use XTracker::Config::Local qw/config_var/;

requires 'is_parsable';
requires 'parse';

requires '_get_timezoned_date';
requires '_translate_time';
requires '_set_order_postage';
requires '_set_order_date';
requires '_set_channel_name';
requires '_order_data_key_mapping';

sub _get_order_data {
    my ($self, $node) = @_;

    my %keys = %{ $self->_order_data_key_mapping };

    my $data = $self->_extract(\%keys,$node);

    $self->_set_order_postage($node, $data);
    $self->_set_order_date($data);
    $self->_set_channel_name($data);

    return $data;
}

sub _set_order_date {
    my ($self, $data) = @_;

    # FIXME: we are getting orders with dates with no timezone - however they
    # FIXME: currently 'Europe/London' and here we are immediately assigning
    # FIXME: a useful timezoned datetime
    $data->{order_date} =
        $self->_get_timezoned_date(
            $data->{order_date},
            config_var("DistributionCentre", "timezone"),
        );

}

sub _set_channel_name {
    my ($self, $data) = @_;

    # cos the people generating the payload have no sense of pride in their
    # work I'm going to tie this down
    # (cos the people complaining about lack of pride have no pride
    # themselves, changing this to something cleaner ;-) CCW)
    $data->{channel} =~ s{\AJCHOO\.(INTL|AM)\z}{JC-\U$2\E}i
        if defined $data->{channel};
}

sub __unimplemented_FIXME {
    my ($self, $data) = @_;

    # FIXME:
    #        basket_id              = $order_data->{order_nr};
    #        ip_address             = $node->findvalue('@CUST_IP');
    #        placed_by              = $node->findvalue('@LOGGED_IN_USERNAME');
    #    $order_data->{used_stored_card}       = $node->findvalue('@USED_STORED_CREDIT_CARD');

    #    ### legacy card info
    #    $order_data->{sticker}
    #        = $node->findvalue('DELIVERY_DETAILS/STICKER');
    #
    #    # DC specific fields
    #    # FIXME how best to incorporate this?
    #    if ( $self->dc() eq 'DC2' ) {
    #        $order_data->{order_date}
    #            = _get_est_date( $node->findvalue('@ORDER_DATE') );
    #        $order_data->{use_external_tax_rate}
    #            = $node->findvalue('@USE_EXTERNAL_SALETAX_RATE') || 0;
    #    }
    #    else { # Default to reading value from XML file
    #        $order_data->{order_date} = $node->findvalue('@ORDER_DATE');
    #        # This is DC1 specific
    #        $order_data->{premier_routing_id}
    #            = $node->findvalue('@PREMIER_ROUTING_ID');
    #
    #        $order_data->{premier_routing_id} = undef
    #            if $order_data->{premier_routing_id} eq '';
    #    }
    #
    #    print "Processing Order: ".$order_data->{order_nr}."\n";
    #
    #    # order totals and currency
    #    $order_data->{gross_total}    = $node->findvalue('GROSS_TOTAL/VALUE');
    #    $order_data->{gross_shipping} = $node->findvalue('POSTAGE/VALUE');
    #    $order_data->{currency}       = $node->findvalue('GROSS_TOTAL/VALUE/@CURRENCY');
    #

    return $data;
}

1;
