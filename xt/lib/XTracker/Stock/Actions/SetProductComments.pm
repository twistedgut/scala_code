package XTracker::Stock::Actions::SetProductComments;

use strict;
use warnings;
use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Database::Product qw( create_product_comment );
use XTracker::Utilities                 qw( url_encode );
use XTracker::Error;

# Job Q Stuff
use XT::JQ::DC;

sub handler {
    my $handler     = XTracker::Handler->new( shift );

    # set default redirect url

    $handler->{data}{redirect_url} = $handler->{referer};

    if ( $handler->{param_of}{product_id} && $handler->{param_of}{comment} ) {

        eval {

            my $guard = $handler->schema->txn_scope_guard;
            create_product_comment( $handler->{dbh},
                {
                    product_id      => $handler->{param_of}{product_id},
                    operator_id     => $handler->{data}{operator_id},
                    department_id   => $handler->{data}{department_id},
                    comment         => $handler->{param_of}{comment}
                }
            );

            my $job_payload = {
                            username        => $handler->{data}{username},
                            product_id      => $handler->{param_of}{product_id},
                            comment         => $handler->{param_of}{comment},
                            action          => 'add'
                    };
            my $job = $handler->create_job( "Send::Product::Comment", $job_payload );

            $guard->commit;
            xt_success("Product Comment Created");
        };

        # db updates not successful
        if ($@) {
            xt_warn("There was a problem trying to create the comment, please try again.<br /><br />$@");
        }

    }

    return $handler->redirect_to( $handler->{data}{redirect_url} );
}

1;

__END__
