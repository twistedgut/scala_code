package XTracker::Order::Actions::UpdateCustomer;

use NAP::policy 'tt';

use XTracker::Handler;
use XTracker::Database::Customer;
use XTracker::Utilities qw( parse_url unpack_csm_changes_params );
use XTracker::Error;
use XTracker::Database::Utilities;
use XT::Net::Seaview::Client;
use XT::Net::Seaview::Utils;
use XT::Net::Seaview::Exception::ResourceError;
use XT::Net::Seaview::Exception::ClientError;
use XTracker::Logfile qw/xt_logger/;

=head1 NAME

XTracker::Order::Actions::UpdateCustomer

=head1 DESCRIPTION

Form handler to update customer details both in the local XT database and in
the Seaview service

=cut

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    my $schema = $handler->schema;
    # Seaview client
    $handler->{seaview}
      = XT::Net::Seaview::Client->new({schema => $schema});

    # get current section info
    my ($section, $subsection, $short_url) = parse_url($r);

    my $customer_id         = $handler->{param_of}{customer_id};
    my $signature           = $handler->{param_of}{signature} || 0;
    my $marketing_contact   = $handler->{param_of}{marketing_contact};
    my $category_id         = $handler->{param_of}{category_id};
    my $redirect            = $short_url.'/CustomerView?customer_id='.$customer_id;
    my $success             = "";

    eval {

        die "The customer ID ($customer_id) does not look like it's valid"
            unless is_valid_database_id( $customer_id );

        my $guard = $schema->txn_scope_guard;
        my $customer = $handler->schema->resultset('Public::Customer')->find( $customer_id )
            || die "Customer ID $customer_id does not exist";

        if ( exists( $handler->{param_of}{update_marketing_options} ) ) {

            set_marketing_contact_date( $schema->storage->dbh, $customer_id, $marketing_contact || "" );

            if ( $handler->{param_of}{marketing_high_value} ) {
            # If 'New High Value' has been ticked, add the flag.

                $customer->set_new_high_value_action( {
                    operator_id => $handler->operator_id,
                } );

            }

            $success = "Marketing Options Updated";

        }
        elsif ( $category_id ) {

            # Update local database
            update_local_customer_category($handler, $customer_id, $category_id);

            # Update seaview if we have a linked account
            $customer->update_seaview_account($category_id);

            # set_customer_category( $handler->{dbh}, $customer_id, $category_id );
            $success    = "Customer Category Updated";
        }
        elsif ( exists( $handler->{param_of}{update_contact_options} ) ) {
            my $csm_changes = unpack_csm_changes_params( $handler->{param_of} );
            my $any_changes = 0;
            foreach my $subject_id ( keys %{ $csm_changes } ) {
                $any_changes    += $customer->ui_change_csm_available_by_subject( $subject_id, $csm_changes->{ $subject_id } );
            }
            $success    = "Order Contact Options Updated"       if ( $any_changes );
        }

        $guard->commit();
        xt_success( $success );
    };

    if ( my $err = $@ ) {
        xt_die("An error occurred whilst updating the customer record:<br />$err");
    }

    return $handler->redirect_to( $redirect );
}

=head2 update_local_customer_category

Update the customer category in the local database

=cut

sub update_local_customer_category {
    my ( $handler, $customer_id, $category_id ) = @_;

    my $schema = $handler->{schema};

    # Find customer
    my $local_customer
      = $schema->resultset('Public::Customer')->find($customer_id);

    # Update local db
    $local_customer->update({category_id => $category_id});

    return;
}

