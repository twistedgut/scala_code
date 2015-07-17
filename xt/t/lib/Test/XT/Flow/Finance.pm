package Test::XT::Flow::Finance;

use NAP::policy "tt",     qw( test role );

requires 'mech';
requires 'note_status';
requires 'config_var';

with 'Test::XT::Flow::AutoMethods';

=head1 NAME

Test::XT::Flow::Finance

=head1 METHODS

=head2 flow_mech__finance__reimbursements

    Fetch the Finance/Reimbursements page.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__finance__reimbursements',
    page_description => 'Finance Reimbursements',
    page_url         => '/Finance/Reimbursements',
);

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__finance__reimbursements_submit',
    form_name         => 'bulk_reimbursement',
    form_description  => 'bulk reimbursement',
    assert_location   => qr!/Finance/Reimbursements!,
    transform_fields  => sub {
        my ($self, $fields) = @_;

        # to maintain backward compatibility
        # need to change the 'notes' to 'reason'
        $fields->{reason}   = delete $fields->{notes};

        return $fields;

    },
);

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__finance__reimbursements__bulk_confirm',
    page_description => 'Finance Reimbursements Bulk Confirm',
    page_url         => '/Finance/Reimbursements/BulkConfirm',
);

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__finance__reimbursements__bulk_confirm_submit',
    form_name         => 'bulk_reimbursement_confirm',
    form_description  => 'bulk reimbursement confirm',
    assert_location   => qr!/Finance/Reimbursements/BulkConfirm!,
    transform_fields  => sub {
        my ($self, $fields) = @_;

        return $fields;

    },
);

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__finance__activeinvoices',
    page_description => 'Finance Active Invoices',
    page_url         => '/Finance/ActiveInvoices',
);



__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__finance___activeInvoice_submit',
    form_name         => sub {
        my ($self, $action, $renum_id, $channel_config) = @_;

        return "activeInvoiceForm-".$channel_config;
    },
    form_description  => 'Fincace Active invoice form',
    assert_location   => qr!/Finance/ActiveInvoices!,
    transform_fields  => sub {
        my ($self, $action, $renum_id, $channel_config) = @_;

        my $text = $action . "-" . $renum_id;
        return { $text => 1 };

    },
);


__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__finance___update_preorder_Invoice_submit',
    form_name         => "refundForm",
    form_description  => 'Finance Active invoice form',
    assert_location   => qr!/Finance/ActiveInvoices/PreOrderInvoice!,
    transform_fields  => sub {
        my ($self, $action, $status_id) = @_;

        return { $action => $status_id };
    },
);

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__finance___refundForm_submit',
    form_name         => 'refundForm',
    form_description  => 'Edit invoice form',
    assert_location   => qr!/Finance/ActiveInvoices/Invoice!,
    transform_fields  => sub {
        my ($self, $action, $status_id) = @_;

        return { $action => $status_id };

    },
);

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__finance__edit_preorder_invoice',
    link_description => 'Edit PreOrder Invoice',
    assert_location  => qr!^/Finance/ActiveInvoices!,
    transform_fields => sub {
        my $preorder_id = $_[1];
        my $invoice_id  = $_[2];
        note "PreOrder ID: $preorder_id";
        note "Invoice ID: $invoice_id";
        return {
                 url_regex => qr!^/Finance/ActiveInvoices/PreOrderInvoice\?preorder_id=$preorder_id\&action=Edit\&invoice_id=${invoice_id}$!,}
        }
);

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__finance__edit_invoice',
    link_description => 'Edit Invoice',
    assert_location  => qr!^/Finance/ActiveInvoices!,
    transform_fields => sub {
        my $order_id    = $_[1];
        my $shipment_id = $_[2];
        my $invoice_id  = $_[3];
        note "Order ID: $order_id";
        return {
                 url_regex => qr!^/Finance/ActiveInvoices/Invoice\?order_id=$order_id\&shipment_id=$shipment_id\&action=Edit\&invoice_id=${invoice_id}$!,}
        }


);


=head2 flow_mech__finance__pre_authorise_order

This follows the 'Pre-Authorise Order' link on the Order View page shown for 'Finance' department
users only when an Order has a Credit Card payment.

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__finance__pre_authorise_order',
    link_description => 'Pre-Authorise Order',
    find_link        => { text => 'Pre-Authorise Order' },
    assert_location  => qr!^/.*/.*/OrderView!,
);

=head2 flow_mech__finance__new_preauth_submit

This submits a New Pre-Auth Request. Pass in the Required Fields or leave absent to test for Validation errors.

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__finance__new_preauth_submit',
    form_name         => 'editPayment',
    form_description  => 'New Pre-Auth Request',
    assert_location   => qr!^/.*/.*/AuthorisePayment\??.*!,
    form_button       => 'action',
    transform_fields  => sub {
        my ($self, $fields ) = @_;

        my $ret_fields  = $fields;
        $ret_fields->{action} = 'SUBMIT';

        return $ret_fields;
    },
);

=head2 flow_mech__finance__cancel_preauth_submit

This attempts to Cancel a Pre-Auth.

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__finance__cancel_preauth_submit',
    form_name         => 'cancelPayment',
    form_description  => 'Cancel a Pre-Auth',
    assert_location   => qr!^/.*/.*/AuthorisePayment\??.*!,
    form_button       => 'action',
    transform_fields  => sub {
        my $self    = shift;

        return { action => 'CANCEL' };
    },
);

=head2 flow_mech__finance__fraud_hotlist

Goes to the 'Finance->Fraud Hotlist' menu option.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__finance__fraud_hotlist',
    page_description => 'Finance Fraud Hotlist',
    page_url         => '/Finance/FraudHotlist',
);

=head2 flow_mech__finance__fraud_hotlist_add_entry

Adds an entry on the 'Finance->Fraud Hotlist' page.

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__finance__fraud_hotlist_add_entry',
    form_name         => 'add_form',
    form_description  => 'Add Fraud Hotlist Entry',
    assert_location   => qr!^/Finance/FraudHotlist!,
    form_button       => 'submit',
    transform_fields  => sub {
        my ($self, $fields ) = @_;
        return $fields;
    },
);

=head2 flow_mech__finance__fraud_hotlist_delete_entry

Deletes an entry on the 'Finance->Fraud Hotlist' page.

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__finance__fraud_hotlist_delete_entry',
    form_name         => sub {
        my ( $self, $hotlist_field, $fields ) = @_;
        return "delete_form_${hotlist_field}";
    },
    form_description  => 'Delete Fraud Hotlist Entry',
    assert_location   => qr!^/Finance/FraudHotlist!,
    form_button       => 'submit',
    transform_fields  => sub {
        my ( $self, $hotlist_field, $fields ) = @_;
        return $fields;
    },
);

=head2 flow_mech__finance__fraud_rules

Goes to the 'Finance->Fraud Rules' menu option.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__finance__fraud_rules',
    page_description => 'Finance - Fraud Rules',
    page_url         => '/Finance/FraudRules',
);

=head2 flow_mech__finance__fraud_rules__bulk_test

Goes to the 'Finance->Fraud Rules->Bulk Test' menu option.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__finance__fraud_rules__bulk_test',
    page_description => 'Finance - Fraud Rules - Bulk Test',
    page_url         => '/Finance/FraudRules/BulkTest',
);



=head2 flow_mech__finance__fraud_rules__bulk_test__test_submit

Submits the Fraud Rule test on the 'Finance->Fraud Rules->Bulk TEst' page.

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__finance__fraud_rules__bulk_test__test_submit',
    form_name         => 'bulk_test',
    form_description  => 'Submit Bulk Test',
    assert_location   => qr!^/Finance/FraudRules/BulkTest!,
    form_button       => 'submit',
    transform_fields  => sub {
        my ($self, $fields ) = @_;
        return $fields;
    },
);

=head2 flow_mech__finance__credit_check

Goes to the 'Finance->Credit Check' menu option.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__finance__credit_check',
    page_description => 'Credit Check',
    page_url         => '/Finance/CreditCheck',
);

=head2 flow_mech__finance__pending_invoices

Goes to the 'Finance->Pending Invoices' menu option.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__finance__pending_invoices',
    page_description => 'Pending Invoices',
    page_url         => '/Finance/PendingInvoices',
);

=head2 flow_mech__finance__credit_hold

Goes to the 'Finance->Credit Hold' menu option.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__finance__credit_hold',
    page_description => 'Credit Hold',
    page_url         => '/Finance/CreditHold',
);

=head2 flow_mech__finance__transaction_reporting

Goes to the 'Finance->Transaction Reporting' menu option.

=cut

__PACKAGE__->create_fetch_method(
    method_name         => 'flow_mech__finance__transaction_reporting',
    page_description    => 'Transaction Reporting',
    page_url            => '/Finance/TransactionReporting',
);

=head2 flow_mech__finance__credit_hold__view_bulk_action_log

Goes to the 'View Bulk Action Log' left hand menu option on the 'Finance->Credit Hold' page.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__finance__credit_hold__view_bulk_action_log',
    page_description => 'View Bulk Action Log',
    page_url         => '/Finance/CreditHold/ViewBulkActionLog',
);

=head2 flow_mech__finance__fraud_rules__list_manager

Goes to the 'Finance -> Fraud Rules -> List Manager' menu option.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__finance__fraud_rules__list_manager',
    page_description => 'Finance - Fraud Rules - List Manager',
    page_url         => '/Finance/FraudRules/ListManager',
);

=head2 flow_mech__finance__fraud_rules__list_manager__submit_form

Submits the form on the 'Finance -> Fraud Rules -> List Manager' page.

    flow_mech__finance__fraud_rules__list_manager__submit_form( {
        list_name        => 'First Test List',
        list_description => 'First Test List',
        list_type_id     => $list_type->id,
        list_type_values => \@some_selected_values,
    } );

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__finance__fraud_rules__list_manager__submit_form',
    form_name         => 'fraud_lists__list_manager__list',
    form_description  => 'Submit List Manager Form',
    assert_location   => qr!^/Finance/FraudRules/ListManager!,
    form_button       => 'submit',
    transform_fields  => sub {
        my ($self, $fields ) = @_;

        my $list_type_id     = $fields->{list_type_id};
        my $list_type_values = delete $fields->{list_type_values};

        if ( $list_type_id && ref( $list_type_values ) eq 'ARRAY' ) {
        # If some values for this list type are required.

            # Tick the checkboxes for all the requested values.
            $self->mech->tick( "list_value_$list_type_id", $_ )
                foreach @$list_type_values;

        }

        return $fields;

    },
);

=head2 flow_mech__finance__fraud_rules__list_manager__edit_list


=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__finance__fraud_rules__list_manager__edit_list',
    link_description => 'Edit List',
    assert_location  => qr!^/Finance/FraudRules/ListManager!,
    transform_fields => sub {
        my ( $mech, $list_id ) = @_;
        return { url_regex => qr|ListManager\?action=edit\&list_id=$list_id| };
    },
);


=head2 flow_mech__finance__fraud_rules__list_manager__delete_list


=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__finance__fraud_rules__list_manager__delete_list',
    link_description => 'Delete List',
    assert_location  => qr!^/Finance/FraudRules/ListManager!,
    transform_fields => sub {
        my ( $mech, $list_id ) = @_;
        return { url_regex => qr|ListManager\?action=delete\&list_id=$list_id| };
    },
);

=head2 flow_mech__finance__invalid_payments

Goes to the 'Finance->Invalid Payments' menu option.

=cut

__PACKAGE__->create_fetch_method(
    method_name         => 'flow_mech__finance__invalid_payments',
    page_description    => 'Invalid Payments',
    page_url            => '/Finance/InvalidPayments',
);

=head2 flow_mech__finance__store_credit

Goes to the 'Finance->Store Credits' menu option.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__finance__store_credit',
    page_description => 'Store Credit Page',
    page_url         => '/Finance/StoreCredits',
);

=head2 flow_mech__finance__create_store_credit

Follows 'Create Store Credit' link on 'Finance->Store Credits' page.

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__finance__create_store_credit',
    link_description => 'Create Store Credit',
    find_link        => { text => 'Create Store Credit' },
    assert_location  => qr!/Finance/StoreCredits!,
);

=head2 flow_mech__finance__create_store_credit_submit

Submits the 'Create Store Credit' page.

=cut


__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__finance__create_store_credit_submit',
    form_name         => 'create_store_credit',
    form_description  => 'Create Store Credit',
    assert_location   => qr!/Finance/StoreCredits!,
    transform_fields  => sub {
        my ($self, $fields) = @_;

        return $fields;
    }
);
1;

