package XTracker::Order::AJAX::FraudRules;

use NAP::policy "tt";

use XTracker::Constants::Ajax   qw( :ajax_messages );
use XTracker::Logfile           qw( xt_logger );
use Plack::App::FakeApache1::Constants qw(:common HTTP_METHOD_NOT_ALLOWED);
use JSON;
use XT::FraudRules::Actions::Staging;
use XTracker::Handler;
use XTracker::Utilities qw (summarise_stack_trace_error);


=head1 METHODS

=head2 handler

Provides an AJAX wrapper for all actions for FraudRules

=cut


sub handler {
    my $r = shift;

    my $handler = XTracker::Handler->new($r);

    if ($r->method eq 'POST') {

        xt_logger->debug('Calling XT::FraudRules::Actions::Staging module with action :'. $handler->{param_of}{action});

        my $payload = $handler->{param_of}{ruleset} || '[]';
        my $action_obj;

        my $err;

        # JSON Parser Error
        try {
            $payload = from_json( $payload );
            $err = 0;
        }
        catch {
            xt_logger->error( "JSON Parser Error for Payload => '$payload'\n". $_ );
            $r->print(encode_json({
                ok     => 0,
                error_msg => "Data Parser Error. Please contact Service Desk:\n" . summarise_stack_trace_error($_),
            }));
            $err = 1;
        };
        return OK if $err;

        # Object instantiation Error
        try {
            $action_obj =  XT::FraudRules::Actions::Staging->new({
                schema       => $handler->schema,
                ruleset_json => $payload,
            });
            $err = 0;
        }
        catch {
            xt_logger->error( "Object Instantiation Error for Payload => '$payload'\n". $_ );
            $r->print(encode_json({
                ok     => 0,
                error_msg => "Invalid Data Passed. Please contact Service Desk:\n". summarise_stack_trace_error($_),
            }));
            $err = 1;
        };
        return OK if $err;

        # Database Error
        try {
            $handler->schema->txn_do( sub {

                # Determine what method to call on the Staging object based on the
                # action parameter.
                given ( lc $handler->{param_of}{action} ) {

                    when ( 'save' ) {

                        $handler->{data}{output} = $action_obj->validate_and_save(
                            # Adding zero to numify the JSON boolean object.
                            from_json( $handler->{param_of}{force_commit} || 'false' ) + 0
                        );

                    }

                    when ( 'pull_from_live' ) {

                        $handler->{data}{output} = $action_obj->pull_from_live;

                    }

                    when ( 'push_to_live' ) {

                        $handler->{data}{output} = $action_obj->push_to_live(
                            $handler->operator_id,
                            # TODO: remove this hard coded message once the front end
                            # provides it.
                            $handler->{param_of}{log_message} || 'No log message provided'
                        );

                    }

                    default {
                    # If it's an unknown action, let the object decide what's the best
                    # thing to do.

                        $handler->{data}{output} = $action_obj->unknown_action(
                            $handler->{param_of}{action}
                        );

                    }

                }

                $r->print( encode_json($handler->{data}{output}) );
            });
        }
        catch {
         xt_logger->error( "Action '".$handler->{param_of}{action}. "' failed with Payload => '$payload'\n" . $_ );
         $r->print(encode_json({
             ok     => 0,
             error_msg => "'" . $handler->{param_of}{action} . "' Failed. Please Try Again Later:\n". summarise_stack_trace_error($_),
         }));
       };

    } else {
        xt_logger->debug( "HTTP method not supported : ". $r->method);
        return HTTP_METHOD_NOT_ALLOWED;
    }

    return OK;

}
