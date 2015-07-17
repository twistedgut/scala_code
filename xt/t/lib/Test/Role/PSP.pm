package Test::Role::PSP;

use NAP::policy     qw( test role );

requires 'get_schema';

=head1 NAME

Test::Role::PSP - a Moose role to do PSP Related Stuff

=head1 SYNOPSIS

    package Test::Foo;

    with 'Test::Role::PSP';

    __PACKAGE__->get_new_psp_refs;

=cut

use XTracker::Constants             qw( :psp_default );
use XTracker::Constants::FromDB     qw( :orders_payment_method_class );

use Clone                           qw( clone );
use Data::UUID;
use JSON;


=head1 METHODS

=head2 get_psp_end_point

    $string = __PACKAGE__->get_psp_end_point( 'Cancel Payment' );

Returns the actual End Point that the Payment Service uses to talk
to the PSP on for a Type of Action.

Uses this if checking which End Points were used when doing Blackbox
testing and mocking LWP.

=cut

sub get_psp_end_point {
    my ( $self, $action ) = @_;

    my %end_points_map = (
        'Update Basket'         => '/payment-amendment',
        'Cancel Payment'        => '/cancel',
        'Value Threshold Check' => '/exceeds-provider-threshold',
        'Item Replacement'      => '/orderItem/replacement',
        'Validate Address'      => '/reauthorise/address',
    );

    $action //= '';
    croak "No PSP End Point for Action: '${action}'"
                if ( !exists( $end_points_map{ $action } ) );

    return $end_points_map{ $action };
}

=head2 get_general_psp_success_response

    $json_string = __PACKAGE__->get_general_psp_success_response( $hash_ref );

Returns a JSON encoded String that contains the general PSP Success
Response, which is as follows:

    {
        returnCodeResult => 1,
        returnCodeReason => 'Success',
    }

Pass in any extra values to add to the above using '$hash_ref'.

=cut

sub get_general_psp_success_response {
    my ( $self, $extra_args ) = @_;

    return JSON->new->encode( {
        returnCodeResult => 1,
        returnCodeReason => 'Success',
        ( ref( $extra_args ) eq 'HASH' ? %{ $extra_args } : () ),
    } );
}

=head2 get_general_psp_failure_response

    $json_string = __PACKAGE__->get_general_psp_failure_response( $hash_ref );

Returns a JSON encoded String that contains the general PSP Response
Response, which is as follows:

    {
        returnCodeResult => 2,
        returnCodeReason => 'Failure',
    }

Pass in any extra values to add to the above using '$hash_ref'.

=cut

sub get_general_psp_failure_response {
    my ( $self, $extra_args ) = @_;

    return JSON->new->encode( {
        returnCodeResult => 2,
        returnCodeReason => 'Failure',
        ( ref( $extra_args ) eq 'HASH' ? %{ $extra_args } : () ),
    } );
}

=head2 get_new_psp_refs() : {:psp_ref :preauth_ref :settle_ref}

Will get a new set of References which can be used for the C<pre_order_payment>
table or the C<orders.payment> table.

returns:
    {
        psp_ref     => value,
        preauth_ref => value,
        settle_ref  => value,
    }

=cut

sub get_new_psp_refs {
    my $ug = Data::UUID->new;
    return { map { $_ => $ug->create_str } qw/psp_ref preauth_ref settle_ref/ };
}

=head2 create_payment_for_order

    $payment_rec = __PACKAGE__->create_payment_for_order( $order_rec, {
        psp_ref         => $psp_reference,
        preauth_ref     => $preauth_reference,
        # to specify a Payment Method from the 'orders.payment_method'
        # table pass it in to this optional argument, it will default
        # to 'Credit Card' if not present
        payment_method  => payment_method_rec,
    } );

Using the PSP References that you can get with calling 'get_new_psp_refs' you can
create an 'orders.payment' record for an Order.

=cut

sub create_payment_for_order {
    my ( $self, $order, $args ) = @_;

    my $payment_method = delete $args->{payment_method} //
        $self->get_schema->resultset('Orders::PaymentMethod')
                ->find( {
        payment_method => $PSP_DEFAULT_PAYMENT_METHOD,
    } );

    my $payment_args = clone( $args );

    return $order->create_related( 'payments', {
        psp_ref           => delete $payment_args->{psp_ref},
        preauth_ref       => delete $payment_args->{preauth_ref},
        payment_method_id => $payment_method->id,
        %{ $payment_args },
    } );
}

=head2 get_cc_and_third_party_payment_methods

    $hash_ref = __PACKAGE__->get_cc_and_third_party_payment_methods();

Returns a Credit Card & a Third Party Payment Method in a Hash Ref:

    {
        credit_card => $dbic_record,    # both will be:
        third_party => $dbic_record,    # 'Result::Orders::PaymentMethod'
    }

=cut

sub get_cc_and_third_party_payment_methods {
    my $self    = shift;

    my $schema = $self->get_schema;

    # return an example of each class of payment method
    my $credit_card = $schema->resultset('Orders::PaymentMethod')
                                ->search( {
        payment_method_class_id => $ORDERS_PAYMENT_METHOD_CLASS__CARD,
    } )->first;
    my $third_party = $schema->resultset('Orders::PaymentMethod')
                                ->search( {
        payment_method_class_id => $ORDERS_PAYMENT_METHOD_CLASS__THIRD_PARTY_PSP,
    } )->first;

    return {
        credit_card => $credit_card,
        third_party => $third_party,
    };
}

=head2 allow_notifying_psp_of_address_change

    __PACKAGE__->allow_notifying_psp_of_address_change( $payment_rec );

Will change the Payment Method used by the Payment to allow the PSP to
be updated when there is an Address change.

=cut

sub allow_notifying_psp_of_address_change {
    my ( $self, $payment ) = @_;

    my $payment_method = $payment->discard_changes->payment_method;

    # store the original state, if not already stored
    $self->_store_original_state( 'notify_psp_of_address_change', $payment_method );

    $payment_method->update( { notify_psp_of_address_change => 1 } );

    return;
}

=head2 dont_allow_notifying_psp_of_address_change

    __PACKAGE__->dont_allow_notifying_psp_of_address_change( $payment_rec );

Will change the Payment Method used by the Payment to not update the PSP
when there is an Address change.

=cut

sub dont_allow_notifying_psp_of_address_change {
    my ( $self, $payment ) = @_;

    my $payment_method = $payment->discard_changes->payment_method;

    # store the original state, if not already stored
    $self->_store_original_state( 'notify_psp_of_address_change', $payment_method );

    $payment_method->update( { notify_psp_of_address_change => 0 } );

    return;
}

=head2 allow_editing_of_billing_address_for_payment

    __PACKAGE__->allow_editing_of_billing_address_for_payment( $payment_rec );

Will change the Payment Method used by the Payment to allow Billing Address
to be Edited.

=cut

sub allow_editing_of_billing_address_for_payment {
    my ( $self, $payment ) = @_;

    # using 'billing_and_shipping_address_always_the_same' to
    # flag to infer that the Billing Address can be Edited
    return $self->change_payment_to_allow_shipping_and_billing_address_to_be_different( $payment );
}

=head2 prevent_editing_of_billing_address_for_payment

    __PACKAGE__->prevent_editing_of_billing_address_for_payment( $payment_rec );

Will change the Payment Method used by the Payment to prevent the Billing Address
from being Edited.

=cut

sub prevent_editing_of_billing_address_for_payment {
    my ( $self, $payment ) = @_;

    # using 'billing_and_shipping_address_always_the_same' to
    # flag to infer that the Billing Address can't be Edited
    return $self->require_payment_to_insist_shipping_and_billing_address_are_same( $payment );
}

=head2 require_payment_to_insist_shipping_and_billing_address_are_same

    __PACKAGE__->require_payment_to_insist_shipping_and_billing_address_are_same( $payment_rec );

Will change the Payment Method used by the Payment to require Billing and Shipping Addresses
are kept the same.

=cut

sub require_payment_to_insist_shipping_and_billing_address_are_same {
    my ( $self, $payment ) = @_;

    my $payment_method = $payment->discard_changes->payment_method;

    # store the original state, if not already stored
    $self->_store_original_state( 'billing_and_shipping_address_always_the_same', $payment_method );

    $payment_method->update( { billing_and_shipping_address_always_the_same => 1 } );

    return;
}

=head2 change_payment_to_allow_shipping_and_billing_address_to_be_different

    __PACKAGE__->change_payment_to_allow_shipping_and_billing_address_to_be_different( $payment_rec );

Will change the Payment Method used by the Payment to NOT require Billing and Shipping Addresses
are kept the same.

=cut

sub change_payment_to_allow_shipping_and_billing_address_to_be_different {
    my ( $self, $payment ) = @_;

    my $payment_method = $payment->discard_changes->payment_method;

    # store the original state, if not already stored
    $self->_store_original_state( 'billing_and_shipping_address_always_the_same', $payment_method );

    $payment_method->update( { billing_and_shipping_address_always_the_same => 0 } );

    return;
}

=head2 change_payment_to_not_allow_change_of_shipping_address_post_settlement

    __PACKAGE__->change_payment_to_not_allow_change_of_shipping_address_post_settlement($payment_rec );

Will change the Payment Method used by the Payment to Allow Editing Shipping Address post Settlement

=cut

sub change_payment_to_allow_change_of_shipping_address_post_settlement {
    my ( $self, $payment ) = @_;

    my $payment_method = $payment->discard_changes->payment_method;

    # store the original state, if not already stored
    $self->_store_original_state( 'allow_editing_of_shipping_address_after_settlement', $payment_method );

    $payment_method->update( { allow_editing_of_shipping_address_after_settlement => 1 } );

    return;


}

=head2 change_payment_to_not_allow_change_of_shipping_address_post_settlement

    __PACKAGE__->change_payment_to_not_allow_change_of_shipping_address_post_settlement($payment_rec );

Will change the Payment Method used by the Payment to Prevent Editing Shipping Address post Settlement

=cut

sub change_payment_to_not_allow_change_of_shipping_address_post_settlement {
    my ( $self, $payment ) = @_;

    my $payment_method = $payment->discard_changes->payment_method;

    # store the original state, if not already stored
    $self->_store_original_state( 'allow_editing_of_shipping_address_after_settlement', $payment_method );

    $payment_method->update( { allow_editing_of_shipping_address_after_settlement => 0 } );

    return;


}

=head2 change_payment_to_require_psp_notification_of_basket_changes

    __PACKAGE__->change_payment_to_require_psp_notification_of_basket_changes( $payment_rec );

Change the Payment Method used by the Payment to require that the PSP is kept up to date
with any Basket changes - such as Cancelling Items.

=cut

sub change_payment_to_require_psp_notification_of_basket_changes {
    my ( $self, $payment ) = @_;

    my $payment_method = $payment->discard_changes->payment_method;

    # store the original state, if not already stored
    $self->_store_original_state( 'notify_psp_of_basket_change', $payment_method );

    $payment_method->update( { notify_psp_of_basket_change => 1 } );

    return;
}

=head2 change_payment_to_not_require_psp_notification_of_basket_changes

    __PACKAGE__->change_payment_to_not_require_psp_notification_of_basket_changes( $payment_rec );

Change the Payment Method used by the Payment to NOT require that the PSP is kept up to date
with any Basket changes - such as Cancelling Items.

=cut

sub change_payment_to_not_require_psp_notification_of_basket_changes {
    my ( $self, $payment ) = @_;

    my $payment_method = $payment->discard_changes->payment_method;

    # store the original state, if not already stored
    $self->_store_original_state( 'notify_psp_of_basket_change', $payment_method );

    $payment_method->update( { notify_psp_of_basket_change => 0 } );

    return;
}

=head2 prevent_payment_from_allowing_store_credit_only_refunds

    __PACKAGE__->prevent_payment_from_allowing_store_credit_only_refunds( $payment_rec );

Change the Payment Method used by the Payment to prevent Store Credit Only Refunds from
being allowed on an Order.

=cut

sub prevent_payment_from_allowing_store_credit_only_refunds {
    my ( $self, $payment ) = @_;

    my $payment_method = $payment->discard_changes->payment_method;

    # store the original state, if not already stored
    $self->_store_original_state( 'allow_full_refund_using_only_store_credit', $payment_method );

    $payment_method->update( { allow_full_refund_using_only_store_credit => 0 } );

    return;
}

=head2 change_payment_to_allow_store_credit_only_refunds

    __PACKAGE__->change_payment_to_allow_store_credit_only_refunds( $payment_rec );

Change the Payment Method used by the Payment to Allow Store Credit Only Refunds on an Order.

=cut

sub change_payment_to_allow_store_credit_only_refunds {
    my ( $self, $payment ) = @_;

    my $payment_method = $payment->discard_changes->payment_method;

    # store the original state, if not already stored
    $self->_store_original_state( 'allow_full_refund_using_only_store_credit', $payment_method );

    $payment_method->update( { allow_full_refund_using_only_store_credit => 1 } );

    return;
}

=head2 prevent_payment_from_allowing_payment_only_refunds

    __PACKAGE__->prevent_payment_from_allowing_payment_only_refunds( $payment_rec );

Change the Payment Method used by the Payment to prevent Payment Only Refunds from
being allowed on an Order.

Payment Only Refunds meaning Card Only or PayPal only Refunds.

=cut

sub prevent_payment_from_allowing_payment_only_refunds {
    my ( $self, $payment ) = @_;

    my $payment_method = $payment->discard_changes->payment_method;

    # store the original state, if not already stored
    $self->_store_original_state( 'allow_full_refund_using_only_store_credit', $payment_method );

    $payment_method->update( { allow_full_refund_using_only_payment => 0 } );

    return;
}

=head2 change_payment_to_allow_payment_only_refunds

    __PACKAGE__->change_payment_to_allow_payment_only_refunds( $payment_rec );

Change the Payment Method used by the Payment to Allow Payment Only Refunds on an Order.

Payment Only Refunds meaning Card Only or PayPal only Refunds.

=cut

sub change_payment_to_allow_payment_only_refunds {
    my ( $self, $payment ) = @_;

    my $payment_method = $payment->discard_changes->payment_method;

    # store the original state, if not already stored
    $self->_store_original_state( 'allow_full_refund_using_only_payment', $payment_method );

    $payment_method->update( { allow_full_refund_using_only_payment => 1 } );

    return;
}

=head2 change_payment_to_allow_goodwill_refund_to_payment

    __PACKAGE__->change_payment_to_allow_goodwill_refund_to_payment( $payment_rec );

Change the Payment Method used by the Payment to Allow Goodwill Refunds to be raised
against the Payment (such as Credit Card).

=cut

sub change_payment_to_allow_goodwill_refund_to_payment {
    my ( $self, $payment ) = @_;

    my $payment_method = $payment->discard_changes->payment_method;

    # store the original state, if not already stored
    $self->_store_original_state( 'allow_goodwill_refund_using_payment', $payment_method );

    $payment_method->update( { allow_goodwill_refund_using_payment => 1 } );

    return;
}

=head2 change_payment_to_not_allow_goodwill_refund_to_payment

    __PACKAGE__->change_payment_to_not_allow_goodwill_refund_to_payment( $payment_rec );

Change the Payment Method used by the Payment to NOT Allow Goodwill Refunds to be raised
against the Payment (such as Credit Card).

=cut

sub change_payment_to_not_allow_goodwill_refund_to_payment {
    my ( $self, $payment ) = @_;

    my $payment_method = $payment->discard_changes->payment_method;

    # store the original state, if not already stored
    $self->_store_original_state( 'allow_goodwill_refund_using_payment', $payment_method );

    $payment_method->update( { allow_goodwill_refund_using_payment => 0 } );

    return;
}

=head2 change_payment_to_cancel_payment_after_force_address_update

    __PACKAGE__->change_payment_to_cancel_payment_after_force_address_update( $payment_rec );

Change the Payment Method used by the Payment to Cancel a Payment when a
force Address Update is used whilst Editing the Shipping Address.

=cut

sub change_payment_to_cancel_payment_after_force_address_update {
    my ( $self, $payment ) = @_;

    my $payment_method = $payment->discard_changes->payment_method;

    # store the original state, if not already stored
    $self->_store_original_state( 'cancel_payment_after_force_address_update', $payment_method );

    $payment_method->update( { cancel_payment_after_force_address_update => 1 } );

    return;
}

=head2 change_payment_to_not_cancel_payment_after_force_address_update

    __PACKAGE__->change_payment_to_not_cancel_payment_after_force_address_update( $payment_rec );

Change the Payment Method used by the Payment to NOT Cancel a Payment when a
force Address Update is used whilst Editing the Shipping Address.

=cut

sub change_payment_to_not_cancel_payment_after_force_address_update {
    my ( $self, $payment ) = @_;

    my $payment_method = $payment->discard_changes->payment_method;

    # store the original state, if not already stored
    $self->_store_original_state( 'cancel_payment_after_force_address_update', $payment_method );

    $payment_method->update( { cancel_payment_after_force_address_update => 0 } );

    return;
}


# Hash Ref that stores the original states for
# various flags so that they can be restored
my $_psp_role_original_state_store = {};

=head2 psp_restore_original_state_for_field

    __PACKAGE__->psp_restore_original_state_for_field( 'flag', $record_obj );

Will restore the Original state of a 'field' for the given Record Object.

=cut

sub psp_restore_original_state_for_field {
    my ( $self, $field, $record ) = @_;

    if ( my $stored = $_psp_role_original_state_store->{ $field }{ $record->id } ) {
        $stored->{record}->discard_changes->update( {
            $field => $stored->{state},
        } );
        # no need to keep storing the Field's original State
        delete $_psp_role_original_state_store->{ $field }{ $record->id };
    }

    return;
}

=head2 psp_restore_all_original_states

    __PACKAGE__->psp_restore_all_original_states();

Will restore the original state of ALL 'field's that have been saved.

=cut

sub psp_restore_all_original_states {
    my $self = shift;

    foreach my $field ( keys %{ $_psp_role_original_state_store } ) {
        my $field_store = $_psp_role_original_state_store->{ $field };
        foreach my $rec_id ( keys %{ $field_store } ) {
            $self->psp_restore_original_state_for_field( $field, $field_store->{ $rec_id }{record} );
        }
    }

    return;
}


# method that stores the original state of a flag,
# this first checks to see if the flag has already
# been set for the Record's Id, if it has then it
# won't stamp on it, using the theory the first
# attempt to store the flag must be the original
sub _store_original_state {
    my ( $self, $flag, $record ) = @_;

    if ( !exists $_psp_role_original_state_store->{ $flag }{ $record->id } ) {
        $_psp_role_original_state_store->{ $flag }{ $record->id } = {
            record => $record,
            state  => $record->$flag,
        };
    }

    return;
}

1;
