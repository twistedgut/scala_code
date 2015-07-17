package XTracker::Sample::Actions::SetSampleCartUserAccess;

use strict;
use warnings;
use Carp;

use XTracker::Handler;
use XTracker::Constants::FromDB                 qw( :department :authorisation_level );
use XTracker::Database::SampleRequest   qw( :SampleUsers list_sample_request_types );
use XTracker::Database::Operator                qw( get_operator_by_id );
use XTracker::Utilities                                 qw( :edit url_encode );
use XTracker::Error;

sub handler {

    my $handler     = XTracker::Handler->new( shift );

    my $ret_url             = "/Sample/SampleCartUsers";

    ## unpack request parameters
    my ($data_ref, $rest_ref)   = unpack_handler_edit_params($handler->{param_of});

    if ( $handler->auth_level == $AUTHORISATION_LEVEL__MANAGER && $handler->department_id == $DEPARTMENT__SAMPLE
            && $rest_ref->{action} eq 'update_user_access' && $rest_ref->{operator_id} =~ m{\A\d+\z}xms ) {

        my $operator_dets;

        eval {

            my @enabled_request_type_ids = ();
            foreach my $key ( keys %{$rest_ref} ) {
                push @enabled_request_type_ids, $1 if $key =~ m{\Arequest_type_id-(\d)\z}xms;
            }

            my $schema = $handler->schema;
            my $dbh = $schema->storage->dbh;
            my $guard = $schema->txn_scope_guard;
            $operator_dets  = get_operator_by_id($dbh,$rest_ref->{operator_id});

            set_user_request_type_access(
                $dbh,
                {
                    operator_id              => $rest_ref->{operator_id},
                    enabled_request_type_ids => \@enabled_request_type_ids
                }
            );
            $guard->commit;
            xt_success("Sample Cart Access Changed for ".$operator_dets->{name});
        };
        if ($@) {
                xt_warn($@);
        }
    }

    return $handler->redirect_to( $ret_url );
}

1;

__END__
