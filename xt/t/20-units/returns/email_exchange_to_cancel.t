#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use FindBin::libs;

=head1 NAME

email_exchange_to_cancel.t - Cancel Exchange Email

=head1 DESCRIPTION

Tests the Email that gets generated when Cancelling an Exchange.

#TAGS goodin return shouldbeunit email cancel

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::Email;

use Catalyst::Utils qw/merge_hashes/;

use XTracker::Config::Local;
use XTracker::Constants::FromDB qw/
    :customer_issue_type
    :correspondence_templates
    :shipment_type
/;

my $domain = Test::XTracker::Data::Email->get_active_mq_producer;

my $channels;
foreach my $channel ( Test::XTracker::Data->get_schema->resultset('Public::Channel')
                ->enabled_channels->all ) {
    $channels->{substr($channel->business->config_section, 0, 3)} = 1;
}

my $prod_data = Test::XTracker::Data->get_pid_set( $channels,
    { dont_ensure_live_or_visible => 1, }
);

my $attrs = [
    { price => 250.00 },
];

foreach my $business ( keys %$channels ) {
    return_to_exchange_then_cancel({ business => $business});
}

done_testing;

sub return_to_exchange_then_cancel {
    my ($args) = @_;

    my $business    = $args->{business};

    my $attibutes = [ $attrs->[0] ];

    my ($return, $order, $si) = Test::XTracker::Data->make_rma({
        base => { channel_id => $prod_data->{ $business }->{channel}->id },
        pids => $prod_data->{$business}{pids},
        attrs => $attibutes
    });

    # Convert to an exchange
    my ( $variant, $size ) = split(/-/, $return->return_items->first->shipment_item->get_sku);
    my $converted = Test::XTracker::Data->convert_return_to_exchange( {
        return_obj      => $return,
        items           => [ {
            id              => $return->return_items->first->id,
            operator_id     => "",
            variant         => $variant,
            size            => $size,
        }, ],
    } );

    ok($converted, "Return converted to exchange");

    note("Return ID is ".$return->id);

    # Now check that there is only one item listed in the return email
    my $content = $domain->render_email( { return => $return }, $CORRESPONDENCE_TEMPLATES__CANCEL_RETURN )->{email_body};

    like($content, qr/item/, "Return contains at least one item ...");
    unlike($content, qr/items/, "... but does not contain multiple items ...");
    my (@items) = $content =~ /^(- .* - size .*)$/mg;
    cmp_ok(@items, '==', 1, "... and contains only 1 item");

    # Cancel the return
    my $cancelled = Test::XTracker::Data->cancel_return( {
        id  => $return->id
    } );

    ok($cancelled, "Return cancelled");
    return 1;
}

1;

