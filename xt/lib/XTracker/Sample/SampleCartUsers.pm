package XTracker::Sample::SampleCartUsers;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants  qw(:common);
use JSON                                qw( to_json );
use XTracker::Handler;
use XTracker::Constants::FromDB         qw( :department :authorisation_level );
use XTracker::Database::SampleRequest   qw( :SampleUsers list_sample_request_types );
use XTracker::Utilities                 qw( :edit );

sub handler {
    my $r = shift;
    my $handler = XTracker::Handler->new($r);

    ## unpack request parameters
    my ($data_ref, $rest_ref)   = unpack_handler_edit_params($handler->{param_of});

    ## tt data
    $handler->{data}{content}               = 'stocktracker/sample/sampleusers.tt';
    $handler->{data}{section}               = 'Sample';
    $handler->{data}{subsection}            = 'Sample Cart Users';
    $handler->{data}{subsubsection}         = "Sample Cart Request Type Access";
    $handler->{data}{yui_enabled}           = 1;
    $handler->{data}{tt_process_block}      = 'display_user_access';
    $handler->{data}{timestring}            = time;

    CASE: {
        if ( $rest_ref->{action} eq 'list_user_access' ) {

            my $user_request_type_access_ref    = list_user_request_type_access( { dbh => $handler->{dbh}, type => 'current' } );
            my $user_request_type_access_json   = to_json({ ResultSet => { Result => $user_request_type_access_ref } }, { pretty => 1, utf8 => 1 });

            $r->print($user_request_type_access_json);
            return OK;

        }
        if ( $handler->auth_level == $AUTHORISATION_LEVEL__MANAGER && $handler->department_id == $DEPARTMENT__SAMPLE
                && $rest_ref->{action} eq 'display_set_user_access' && $rest_ref->{operator_id} =~ m{\A\d+\z}xms ) {

            my $sample_request_types_ref    = list_sample_request_types( { dbh => $handler->{dbh} } );

            my $user_request_type_access_ref
                = list_user_request_type_access({
                        dbh         => $handler->{dbh},
                        type        => $rest_ref->{type},
                        operator_id => $rest_ref->{operator_id},
                });

            $handler->{data}{subsubsection}         = 'Set Sample Cart Request Type Access';
            $handler->{data}{sample_request_types}  = $sample_request_types_ref;
            $handler->{data}{user_access}           = $user_request_type_access_ref;
            $handler->{data}{tt_process_block}      = 'set_user_access';

            ## Add sidenav
            my $sidenav_ref;
            my $sidenav_url = '/Sample/SampleCartUsers';
            push @{ $sidenav_ref->[0]{'None'} }, { title => "Back&nbsp;to&nbsp;User&nbsp;List", url => $sidenav_url };
            $handler->{data}{sidenav}   = $sidenav_ref;

            last CASE;
        }

        my $users_without_request_types_ref = list_users_without_request_types( { dbh => $handler->{dbh} } );
        $handler->{data}{add_new_users}     = $users_without_request_types_ref;

    };

    return $handler->process_template( undef );
}

1;

__END__
