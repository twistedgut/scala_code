package XTracker::Schema::ResultSet::Public::Customer;
# vim: set ts=4 sw=4 sts=4:

use strict;
use warnings;

use Carp qw/ croak /;

use base 'DBIx::Class::ResultSet';

use Moose;
with 'XTracker::Schema::Role::ResultSet::FromText' => { field_name => 'is_customer_number' };
no Moose;

sub search_by_pws_customer_nr {
    $_[0]->search({ is_customer_number => $_[1] });
}

sub search_by_email {
    $_[0]->search({ email => $_[1] });
}

sub add_customer {
    my ( $self, $order ) = @_;

    croak 'Order object required'
        unless $order and ref( $order ) eq 'XT::Data::Order';

    my $channel = $order->channel;

    my $customer = $self->search({
        is_customer_number  => $order->customer_number,
        channel_id          => $channel->id,
    })->first;

    my @telephones = $order->all_billing_telephone_numbers;
    my $updated_customer = $self->update_or_create({
        is_customer_number      => $order->customer_number,
        title                   => $order->billing_name->title,
        first_name              => $order->billing_name->first_name,
        last_name               => $order->billing_name->last_name,
        email                   => $order->billing_email,
        category_id             => ( $customer ? $customer->category_id : $order->get_customer_category->id ),
        telephone_1             => ( $telephones[0] && $telephones[0]->number ),
        telephone_2             => ( $telephones[1] && $telephones[1]->number ),
        telephone_3             => ( $telephones[2] && $telephones[2]->number ),
        group_id                => 1,
        ddu_terms_accepted      => ( $customer ? $customer->ddu_terms_accepted : 0 ),
        legacy_comment          => undef,
        credit_check            => ( $customer ? $customer->credit_check : undef ),
        no_marketing_contact    => undef,
        no_signature_required   => 0,
        channel_id              => $channel->id,
    });

    return $updated_customer;
}

1;
