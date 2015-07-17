package XT::DC::Controller::Finance::Reimbursements;

use Moose;

BEGIN { extends 'Catalyst::Controller' };

use XTracker::Constants::FromDB qw( :bulk_reimbursement_status );
use XTracker::XTemplate;
use DateTime::Format::ISO8601;

use XTracker::Utilities qw( :string ) ;
use XTracker::Config::Local qw( config_var );
use Carp;

=head1 NAME

XT::DC::Controller::Finance::Reimbursements

=head1 DESCRIPTION

Controller for /Finance/Reimbursements.

=head1 METHODS

=over

=item B<root>

Beginning of the chain for Finance/Reimbursements, containing common tasks for all actions.

=cut

# ----- common -----

sub root : Chained('/') PathPart('Finance/Reimbursements') CaptureArgs(0) {
    my ($self, $c) = @_;

    $c->check_access();

    # Copy parameters to stash.
    foreach ( $c->request->param ) {

        my $value = $c->request->param( $_ ) || '';

        # Trim leading/trailing spaces.
        $value = trim( $value );

        # Restore HTML.
        $value =~ s/$_[0]/$_[1]/g
            foreach ( ['&lt;', '<'], ['&gt;', '>'], ['&amp;', '&'], ['&quot;', '"'] );

        $c->stash( $_ => $value );

    }

    # Populate the sidenav.
    $c->stash(
        sidenav => [
            { None => [{ 'title' => 'Bulk', 'url' => "/Finance/Reimbursements"}] }
        ],
    );
}

# ----- bulk -----

=item B<bulk>

Action for Finance/Reimbursements/bulk.

=cut

sub bulk : Chained('root') PathPart('') Args(0) ActionClass('REST') {
    my ($self, $c) = @_;

    # Fetch the channels.
    $c->stash(
        'channels' => [
            $c->model('DB::Public::Channel')
                ->search(
                    {
                        'business.fulfilment_only' => 0
                    },
                    {
                        join => [ 'business' ]
                    }
                )
                ->all
        ],
        'compensation_reasons' => [
            $c->model('DB::Public::RenumerationReason')
                ->get_compensation_reasons( $c->session->{department_id} )
                ->enabled_only
                ->order_by_reason
                ->all
        ],
    );

}

=item B<bulk_GET>

GET REST action for Finance/Reimbursements/bulk.

=cut

sub bulk_GET {
    my ($self, $c) = @_;

    # Clear the session.
    $c->session->{'bulk_reimbursement'} = {};

    # Setup the stash.
    $c->stash->{'send_email'} = '1';

}

=item B<bulk_POST>

POST REST action for Finance/Reimbursements/bulk.

Fetches the orders from the database (determining valid and invalid ones).

=cut

sub bulk_POST {
    my ($self, $c) = @_;

    my $form_ok = 1;
    my $invalid_orders = [];
    my $valid_orders;

    # default to 100 of something, but allow config to beat it
    # however, *don't* allow config to be zero
    my $maximum_credit_value = config_var('Reimbursements', 'maximum_credit_value') || 100;

    # Check the credit amount is valid.
    unless (    $c->stash->{'credit_amount'} =~ /^\d+(\.\d+)?$/
             && $c->stash->{'credit_amount'} > 0
             && $c->stash->{'credit_amount'} <= $maximum_credit_value ) {

        $c->feedback_warn( "Please enter a valid credit amount greater than zero and no more than $maximum_credit_value." );

        $form_ok = 0;
    }

    # Check the Reason has been provided
    unless ( $c->stash->{'invoice_reason_id'} ) {
        $c->feedback_warn('Please select a reason.');
        $form_ok = 0;
    }

    # Check the Notes have been provided
    unless ( $c->stash->{'reason'} =~ /.+/ && length( $c->stash->{'reason'} ) <= 250 ) {
        $c->feedback_warn( 'Please enter valid notes of no more than 250 characters.' );
        $form_ok = 0;
    }

    # Validate the orders.
    if ( $c->stash->{'orders'} =~ /.+/ ) {

        # Get the orders from the DB.
        $valid_orders = $c->model('DB::Public::Orders')->from_text(
            $c->stash->{'orders'},
            $invalid_orders
        );

        # Search for orders that do not match the selected channel.
        my $distinct_channels = $valid_orders->search(
            {
                'channel_id' => { '!=' => $c->stash->{'channel'} }
            }
        );

        # If we found orders from any other channel, warn the user.
        if ( $distinct_channels->count > 0 ) {

            $c->feedback_warn( 'Please enter a list of orders from only the selected channel.' );
            $form_ok = 0;

        }

    } else {

       $c->feedback_warn( 'Please enter a valid list of orders.' );
       $form_ok = 0;

    }

    # If the form was completed correctly.
    if ( $form_ok ) {
        $c->session->{'bulk_reimbursement'} = {
            'send_email'    => $c->stash->{'send_email'} eq '1' ? 1 : 0,
            'channel'       => $c->stash->{'channel'},
            'credit_amount' => $c->stash->{'credit_amount'},
            'invoice_reason_id' => $c->stash->{'invoice_reason_id'},
            'reason'        => $c->stash->{'reason'},
            'order'         => {
                'invalid'       => $invalid_orders,
                'valid'         => [ map { $_->id } $valid_orders->all ],
            },
        };

        $c->response->redirect( $c->uri_for( $self->action_for('bulk_confirm') ) );

    }

}

# ----- bulk_confirm -----

=item B<bulk_confirm>

Action for Finance/Reimbursements/bulk_confirm.

=cut

sub bulk_confirm : Chained('root') PathPart('BulkConfirm') Args(0) ActionClass('REST') {
    my ($self, $c) = @_;

    # Sort the valid orders by currency and order number.
    my $valid_orders = $c->model('DB::Public::Orders')->search(
        {
            'me.id' => {
                '-in' => $c->session->{'bulk_reimbursement'}->{'order'}->{'valid'},
            },
        },
        {
            order_by => { -asc => [ qw( currency.currency order_nr ) ] },
            join => [ qw( currency customer ) ],
            '+columns' => [ qw( currency.currency customer.first_name customer.last_name ) ]
        }
    );

    # Get the selected channel.
    my $channel = $c->model('DB::Public::Channel')->find( $c->session->{'bulk_reimbursement'}->{'channel'} );

    # Get the selected Invoice Reason
    my $invoice_reason = $c->model('DB::Public::RenumerationReason')->find( $c->session->{'bulk_reimbursement'}->{'invoice_reason_id'} );

    $c->stash(
        invalid_orders  => $c->session->{'bulk_reimbursement'}->{'order'}->{'invalid'},
        valid_orders    => _orders_by_currency( [ $valid_orders->all ] ),
        credit_amount   => $c->session->{'bulk_reimbursement'}->{'credit_amount'},
        email_wrapper   => sub { _email_wrapper( $c, $channel->web_name, shift ) },
        channel         => $channel,
        send_email      => $c->session->{'bulk_reimbursement'}->{'send_email'},
        invoice_reason  => $invoice_reason,
        reason          => $c->session->{'bulk_reimbursement'}->{'reason'},
    );

    # Total up each currency.
    $c->stash->{'valid_orders_count'} += @$_ foreach values %{ $c->stash->{'valid_orders'} },

}

=item B<bulk_confirm_GET>

GET REST action for Finance/Reimbursements/bulk_confirm.

=cut


sub bulk_confirm_GET {
    my ($self, $c) = @_;

    # Set email subject dependant on channel config section name.
    if ( $c->stash->{'channel'}->business->config_section eq 'NAP' ) {
        $c->stash->{'email_subject'} = 'Your NET-A-PORTER.COM order update';
    } elsif ( $c->stash->{'channel'}->business->config_section eq 'OUTNET' ) {
        $c->stash->{'email_subject'} = 'Your order update from THE OUTNET';
    } elsif ( $c->stash->{'channel'}->business->config_section eq 'MRP' ) {
        $c->stash->{'email_subject'} = 'Your MR PORTER order update';
    }

    # Set the email message's editable part to be empty by default.
    $c->stash->{'email_message'} = '';

}

=item B<bulk_confirm_POST>

POST REST action for Finance/Reimbursements/bulk_confirm.

Performs checks on form data, displaying errors as appropriate.

=cut

sub bulk_confirm_POST {
    my ($self, $c) = @_;

    my $form_ok = 1;

    # If we're sending an email.
    if ( $c->session->{'bulk_reimbursement'}->{'send_email'} == 1 ) {

        # Check a valid subject was provided.
        unless ( $c->stash->{'email_subject'} =~ /.+/ ) {
            $c->feedback_warn( 'Please enter a valid email subject.' );
            $form_ok = 0;
        }

        # Check a valid message was provided.
        unless ( $c->stash->{'email_message'} =~ /.+/ ) {
            $c->feedback_warn( 'Please enter a valid email message.' );
            $form_ok = 0;
        }

    }

    # If the form was completed correctly.
    if ( $form_ok ) {

        $c->session->{'bulk_reimbursement'}->{'email_subject'} = $c->stash->{'email_subject'};
        $c->session->{'bulk_reimbursement'}->{'email_message'} = $c->stash->{'email_message'};

        $c->response->redirect( $c->uri_for( $self->action_for('bulk_done') ) );

    }

}

# ----- bulk_done -----

=item B<bulk_done>

Action for Finance/Reimbursements/bulk_done.

Populates bulk_reimbursement and link_bulk_reimbursement__orders tables and sends a message to the ActiveMQ queue 'Order::Reimbursement'.

=cut

sub bulk_done : Chained('root') PathPart('BulkDone') Args(0) {
    my ($self, $c) = @_;

    my $bulk_reimbursement;

    eval {

        # Populate bulk_reimbursement table.
        $bulk_reimbursement = $c->model('DB::Public::BulkReimbursement')->create({
            'operator_id'                       => $c->session->{operator_id},
            'channel_id'                        => $c->session->{'bulk_reimbursement'}->{'channel'},
            'bulk_reimbursement_status_id'      => $BULK_REIMBURSEMENT_STATUS__PENDING,
            'credit_amount'                     => $c->session->{'bulk_reimbursement'}->{'credit_amount'},
            'renumeration_reason_id'            => $c->session->{'bulk_reimbursement'}->{'invoice_reason_id'},
            'reason'                            => $c->session->{'bulk_reimbursement'}->{'reason'},
            'send_email'                        => $c->session->{'bulk_reimbursement'}->{'send_email'},
            'email_subject'                     => $c->session->{'bulk_reimbursement'}->{'email_subject'},
            'email_message'                     => $c->session->{'bulk_reimbursement'}->{'email_message'},
            'link_bulk_reimbursement__orders'   => [
                map     { { 'order_id' => $_ } }
                        @{ $c->session->{'bulk_reimbursement'}->{'order'}->{'valid'} }
            ],
        });

        # Send to ActiveMQ.
        $c->model('MessageQueue')->transform_and_send(
            'XT::DC::Messaging::Producer::Order::Reimbursement',
            {
                'reimbursement_id' => $bulk_reimbursement->id
            }
        );

    };

    # If an error occurred.
    if ( my $error = $@ ) {

        carp $error;
        $c->feedback_warn( 'Unable to run report.' );

    } else {

        $c->stash( 'bulk_reimbursement_id', $bulk_reimbursement->id );

        # Clear the session.
        delete $c->session->{'bulk_reimbursement'};

    }

}

=item B<_email_wrapper($c, $channel, $content)>

This is exposed via the stash to the template as 'email_wrapper'. The catalyst context $c and the channel name $channel are passed internally, only $content is required in the template.

The $channel is the column 'web_name' from the public.channel table. The $content will be placed in the 'content' variable in the correspondence template (from public.correspondence_templates), named 'Reimbursement-$channel', which is loaded by this subroutine.

  my $channel = $c->model('DB::Public::Channel')->find( ... );

  $c->stash(
    email_wrapper => sub { _email_wrapper( $c, $channel->web_name, shift ) },
  );

=cut

sub _email_wrapper {
    my ($c, $channel, $content) = @_;
    my $result = '';

    # Load the correspondence template based on the provided $channel.
    my $correspondence_template = $c->model('DB::Public::CorrespondenceTemplate')->find(
        {
            'name' => "Reimbursement-$channel",
        }
    );

    my $template = XTracker::XTemplate->template( { WRAPPER => '' } );

    # If we've got what we need.
    if ( defined $correspondence_template && defined $template ) {

        my $template_content = $correspondence_template->content;

        # Substitute all the new lines with html breaks.
        $template_content =~ s|\n|<br />|g;

        # If there is some content.
        if ( $template_content ) {

            # Provide some dummy data (with the exception of 'content').
            my $data = {
                'plural'    => sub { return uc "&lt;$_[1]/$_[2]&gt;" },
                'content'   => $content,
                'credit'    => {
                    'amount'    => '&lt;CREDIT_AMOUNT&gt;',
                    'currency'  => '&lt;CREDIT_CURRENCY&gt;',
                },
                'customer'  => {
                    'first_name'    => '&lt;CUSTOMER_FIRST_NAME&gt;',
                    'last_name'     => '&lt;CUSTOMER_LAST_NAME&gt;',
                    'title'         => '&lt;CUSTOMER_TITLE&gt;',
                },
            };

            $template->process( \$template_content, $data, \$result );

        }

    }

    return $result;

}

=item B<_orders_by_currency($orders)>

Takes an ArrayRef of orders and returns a HashRef with keys of each currency and values of ArrayRefs containing all the orders for that currency.

  my $orders = $c->model('DB::Public::Orders')->search( ... );

  my $result = _orders_by_currency( [ $orders->all ] );

  $result = {
    'GBP' => [ XTracker::Schema::Result::Public::Orders, ... ],
    'EUR' => [ XTracker::Schema::Result::Public::Orders, ... ],
    ...
  };

=cut

sub _orders_by_currency {
    my ($orders) = @_;
    my $result = {};

    foreach ( @$orders ) {

        push @{ $result->{ $_->currency->currency } }, $_;

    }

    return $result;

}

=back

=cut

1;

