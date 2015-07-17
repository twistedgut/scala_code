package XTracker::Stock::Actions::DeleteProductComment;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database::Product     qw{ delete_product_comment search_product_comments };
use XTracker::Utilities             qw( url_encode );
use XTracker::Error;

### Subroutine : handler                                       ###
# usage        : /Stock/Actions/DeleteProductComment             #
# description  : Deletes a product comment                       #
# parameters   : operator_id, auth_level, product_id, comment_id #

sub handler {
    my $handler     = XTracker::Handler->new( shift );

    # set default redirect url
    $handler->{data}{redirect_url} = $handler->{referer};

    if ( $handler->{param_of}{product_id} && $handler->{param_of}{comment_id} ) {

        eval {
            my $schema = $handler->schema;
            my $dbh = $schema->storage->dbh;
            my $guard = $schema->txn_scope_guard;

            my $comment     = search_product_comments( $dbh, { comment_id => $handler->{param_of}{comment_id} } );
            if ( @{ $comment } != 1 ) {
                die "Couldn't Find Comment";
            }

            my $job_payload = {
                    username    => $comment->[0]{username},
                    product_id  => $comment->[0]{product_id},
                    comment     => $comment->[0]{comment},
                    action      => 'delete'
                };

            delete_product_comment( $dbh, $handler->{param_of}{comment_id} );

            my $job = $handler->create_job( "Send::Product::Comment", $job_payload );

            $guard->commit();
            xt_success("Product Comment Deleted");
        };

        # db updates not successful
        if ($@) {
            xt_warn("There was a problem trying to delete the comment, please try again.<br /><br />$@");
        }
    }

    return $handler->redirect_to( $handler->{data}{redirect_url} );
}

1;
