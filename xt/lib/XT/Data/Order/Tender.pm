package XT::Data::Order::Tender;
use NAP::policy "tt", 'class';

use Data::Dump qw/pp/;

use XT::Domain::Payment;
use XT::Data::Types qw(RemunerationType);

use XTracker::Constants     qw( :psp_default );

=head1 NAME

XT::Data::Order::Tender - A tender for an order for fulfilment

=head1 DESCRIPTION

This class represents a tender for an order that is to be inserted into
XT's order database.

=head1 ATTRIBUTES

=head2 schema

=cut

with 'XTracker::Role::WithSchema';

=head2 id

=cut

has id => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1,
);

=head2 type

Must be one of 'Store Credit', 'Gift Credit', 'Card'

=cut

has type => (
    is          => 'rw',
    isa         => RemunerationType,
    required    => 1,
);

has rank => (
    is          => 'rw',
    isa         => 'Str',
    required    => 1,
);

=head2 value

Attribute is of class L<XT::Data::Money>.

=cut

has value => (
    is          => 'rw',
    isa         => 'XT::Data::Money',
    required    => 1,
);

has voucher_code => (
    is          => 'ro',
    isa         => 'Str',
);


## FIXME hackyhacky defaults so I don't have to rely on code [not] written [yet]
=head2 payment_pre_auth_ref

=cut

has payment_pre_auth_ref => (
    is          => 'rw',
    isa         => 'Str',
    default     => '',
);
has payment_settle_ref => (
    is          => 'rw',
    isa         => 'Str',
    default     => '',
);
has psp_reference => (
    is          => 'rw',
    isa         => 'Str',
    default     => '',
);
has fulfilled => (
    is          => 'rw',
    isa         => 'Bool',
    default     => 0,
);
has valid => (
    is          => 'rw',
    isa         => 'Bool',
    default     => 0,
);

has payment_ws => (
    is          => 'ro',
    isa         => 'XT::Domain::Payment',
    default     => sub { XT::Domain::Payment->new(); },
    lazy        => 1,
);

has payment_info => (
    is          => 'ro',
    isa         => 'HashRef',
    lazy_build  => 1,
);

has provider_reference => (
    is          => 'rw',
    isa         => 'Any',
);

has coin_amount => (
    is          => 'rw',
    isa         => 'Int',
);

has card_type => (
    is          => 'rw',
    isa         => 'Str',
);

has card_number => (
    is          => 'rw',
    isa         => 'Str',
);

has cv2avs_status => (
    is          => 'rw',
    isa         => 'Str',
);

has card_history => (
    is          => 'rw',
    isa         => 'ArrayRef',
    default     => sub { return []; },
);

has payment_method => (
    is          => 'ro',
    isa         => 'XTracker::Schema::Result::Orders::PaymentMethod',
    lazy_build  => 1,
);


# builder for 'payment_info' and will also
# populate 'provider_reference'
sub _build_payment_info {
    my $self    = shift;

    my $payment_info = $self->payment_ws->getinfo_payment({
        reference => $self->payment_pre_auth_ref,
    });

    die "Could not get payment info from PSP: reference: ".$self->payment_pre_auth_ref
        unless ( $self->provider_reference( $payment_info->{providerReference} ) );

    return $payment_info;
}

# builder for 'payment_method'
sub _build_payment_method {
    my $self = shift;

    # get the Payment Method used, from the PSP
    my $method = $self->payment_info->{paymentMethod};

    my $method_rs = $self->schema->resultset('Orders::PaymentMethod');
    my $method_rec;

    if ( $method ) {
        # now search the 'orders.payment_method' table
        # against the 'string_from_psp' field for the Method
        $method_rec = $method_rs->search( {
            'UPPER(string_from_psp)' => uc( $method ),
        } )->first;

        croak "Unknown Payment Method: '" . ( $method // 'undef' ) . "' can't Import Order"
                            if ( !$method_rec );
    }
    else {
        # no Payment Method then use the default
        $method_rec = $method_rs->find( {
            payment_method => $PSP_DEFAULT_PAYMENT_METHOD,
        } );
    }

    return $method_rec;
}


=head2 get_payment_value_from_psp

=cut

sub get_payment_value_from_psp {
    my $self = shift;

    my $payment_info = $self->payment_info;

    $self->coin_amount($payment_info->{coinAmount}) if defined($payment_info->{coinAmount});
    my $card_info = $payment_info->{cardInfo};
    if ( defined( $card_info ) && defined( $card_info->{cardType} ) ) {
        $self->card_type( $card_info->{cardType} );
        my $numxs = ($self->card_type eq 'AMEX' ? 10 : 11);
        $self->card_number(
            $card_info->{cardNumberFirstDigit}.
            ('x' x $numxs).
            $card_info->{cardNumberLastFourDigits}
        );
    }

    $self->cv2avs_status($payment_info->{cv2avsStatus}) if defined($payment_info->{cv2avsStatus});
# JASON

    # FIXME : ask a wsld expert whether there's anything else of interest in cardHistory
    if ( defined( $payment_info->{paymentHistory} ) ) {
        # CANDO-1038: don't include Pre-Orders in the Card History
        my @history = grep { $_ && $_->{orderNumber} && $_->{orderNumber} !~ /pre_order/i }
                                        @{ $payment_info->{paymentHistory} };
        $self->card_history( \@history )        if ( @history );
    }

    $self->type('Card Debit');

    return $self->value;
}

=head2 card_tender_equals_psp_value

    Returns true iff the amount in the tender line and the amount from
    the psp are the same.

=cut

sub card_tender_equals_psp_value {
    my $self = shift;

    return abs(($self->value->value * 100) - $self->coin_amount) <= 1;

}

sub type_id {
    my ( $self ) = @_;

    my $renumeration_type = $self->schema->resultset(
        'Public::RenumerationType'
    )->search({
        type => $self->type,
    })->first->id;
}

=head1 SEE ALSO

L<XT::Data::Order>

=head1 AUTHOR

Pete Smith <pete.smith@net-a-porter.com>

=cut

__PACKAGE__->meta->make_immutable;

1;
