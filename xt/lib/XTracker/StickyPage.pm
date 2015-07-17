package XTracker::StickyPage;
use NAP::policy "tt";

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Config::Local 'config_var';
use XTracker::DBEncode qw( encode_it );
use XTracker::Handler;

sub handler {
    my $r = shift;

    my $handler = XTracker::Handler->new(
        $r, {
            skip_dbl_submit_token_generation => 1,
        }
    );

    # if sticky pages aren't enabled, pass straight through this handler
    return OK unless $handler->{data}{sticky_pages};

    # check for stored sticky page
    if ( my $sticky_page = _stored_sticky_page( $handler ) ) {
        # have one. is it still valid?
        if ( $sticky_page->is_valid ) {
            # yes. does the URL match (if the sticky page has one) ?
            my $request_url = $handler->{data}{path_query};
            my $sticky_url = $sticky_page->sticky_url // '';
            # is this a valid exit?
            if ( not $sticky_page->is_valid_exit_url( $request_url, $handler->{param_of} ) ) {
                # no. should we redirect? (only if sticky_url is set)
                if ( $sticky_url && $request_url ne $sticky_url ) {
                    # yes - redirect to the URL in the sticky page
                    return $handler->redirect_to( $sticky_url );
                }
                my $html = encode_it($sticky_page->html);
                $r->content_type('text/html');
                $r->print($html);
                # and ensure we don't proceed to next handler
                return DONE;
            }
        }

        # if we reach here, the sticky page needs to be deleted
        $sticky_page->delete;
    }

    return OK;
}

sub _stored_sticky_page {
    my $handler = shift;
    # return sticky page for the current operator, if there is one
    return $handler->schema->resultset('Operator::StickyPage')->find($handler->operator_id);
}

1;
