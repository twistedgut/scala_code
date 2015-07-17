package XTracker::Stock::Actions::SendPreOrderEmail;

use strict;
use warnings;

use Try::Tiny;
use URI::Escape;
use Carp;

use XTracker::Handler;
use XTracker::Error;
use XTracker::EmailFunctions        qw( send_customer_email );

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    my $schema      = $handler->schema;

    my $pre_order_id    = $handler->{param_of}{pre_order_id};
    my $template_id     = $handler->{param_of}{template_id};
    my $redirect_url    = $handler->{param_of}{redirect_url};
    my $fail_redirect   = _get_on_fail_redirect_url( $handler->{param_of} );

    my $params          = $handler->{param_of};

    # if any errors with these fields will display the
    # User understandable version in error messages
    my %english_field_names = (
                email_to        => 'To',
                email_from      => 'From',
                email_reply_to  => 'Reply-To',
                email_subject   => 'Subject',
                email_content   => 'Email Text',
            );

    if ( !$params->{send_email} ) {
        xt_info("Did Not Send an Email");
        return $handler->redirect_to( $redirect_url );
    }

    try {
        my $pre_order   = $schema->resultset('Public::PreOrder')->find( $pre_order_id );
        my $template    = $schema->resultset('Public::CorrespondenceTemplate')->find( $template_id );

        if ( !$template ) {
            croak "Couldn't find Template for Id: ${template_id}";
        }

        if ( !$params->{action} || $params->{action} ne 'send_email' ) {
            croak "Missing 'action' parameter or its value is NOT 'send_email'";
        }

        # check all email params have got some values
        foreach my $param ( qw(
                                email_to
                                email_from
                                email_reply_to
                                email_subject
                                email_content
                          ) ) {
            if ( !$params->{ $param } ) {
                croak "Can't send Email: Missing or empty '$english_field_names{$param}'";
            }
        }

        if ( send_customer_email( {
                        to           => $params->{email_to},
                        from         => $params->{email_from},
                        reply_to     => $params->{email_reply_to},
                        subject      => $params->{email_subject},
                        content      => $params->{email_content},
                        content_type => $params->{email_content_type},
                    } ) ) {
            # if email sent successfuly log it
            $pre_order->create_related('pre_order_email_logs', {
                                                        correspondence_templates_id => $template->id,
                                                        operator_id                 => $handler->operator_id,
                                                } );
            xt_success("Email has been Sent");
        }
        else {
            xt_warn("Email could NOT be Sent, please try again");
            $redirect_url   = $fail_redirect;
        }
    }
    catch {
        xt_warn("There was a problem Sending the Email:<br>$_");
        $redirect_url   = $fail_redirect;
    };

    return $handler->redirect_to( $redirect_url );
}


# gets the URL to fallback to if there has been a
# failure and also gets all of the 'passback_*' params
# and attaches them to the URL
sub _get_on_fail_redirect_url {
    my $params      = shift;

    my $redirect_url= '/StockControl/Reservation/PreOrder'
                        . $params->{on_fail_url}
                        . '?pre_order_id=' . $params->{pre_order_id};

    foreach my $passback ( keys %{ $params } ) {
        if ( $passback =~ m/^passback_(.*)/ ) {
            my $name    = $1;
            my $value   = $params->{ $passback };
            $redirect_url   .= '&' . $name . '=' . uri_escape( $value );
        }
    }

    return $redirect_url;
}

1;
