package XTracker::Admin::AJAX::CloneUserAuths;

use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);
use XTracker::Constants::FromDB qw ( :authorisation_section );

use XTracker::Handler;

use XTracker::DBEncode          qw( encode_it );

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $schema          = $handler->{schema};

    my $response        = '';       # response string

    my $op_id_toclone       = $handler->{param_of}{clone_operator_id};
    my $page_operator_id    = $handler->{param_of}{page_operator_id};
    my $operator_id         = $handler->operator_id;
    my $reverting           = $handler->{param_of}{revert} || 0;
    my $oper_dets;

    $op_id_toclone  =~ s/[^0-9]//g;

    # Check if the User you are changing is the same user as doing the change?
    my $same_user = (($page_operator_id//0) == $operator_id ) ? 1 : 0;

    # get the user to clone
    $oper_dets  = $schema->resultset('Public::Operator')->find( $op_id_toclone, { prefetch => 'operator_preference' } )     if ( $op_id_toclone );
    if ( defined $oper_dets ) {
        my %op_auth;
        my %auths;
        my $all_auths   = $schema->resultset('Public::AuthorisationSubSection');
        my $oper_auths  = $schema->resultset('Public::OperatorAuthorisation')->search({ operator_id => $op_id_toclone });

        if( !$reverting ) {
            $oper_auths = $oper_auths->search( {
                'section.id' => { '!=' => $AUTHORISATION_SECTION__ADMIN,},
            },
            {
                join => [ { 'auth_sub_section' =>  'section' },],
            });

            if( $same_user ) {
                $all_auths = $all_auths->search ( {
                    'section.id' => { '!=' => $AUTHORISATION_SECTION__ADMIN,},
                },
                {
                    join => 'section',
                });
            }
        }

        while ( my $row = $oper_auths->next ) {
            $op_auth{ $row->authorisation_sub_section_id }  = $row->authorisation_level_id;
        }

        while ( my $row = $all_auths->next ) {
            $auths{ $row->id }  = ( exists $op_auth{ $row->id } ? $op_auth{ $row->id } : 0 );
        }

        $response   = "{'status':'OK',";
        $response   .= "'revert':".$reverting.",";

        if ( defined $oper_dets->operator_preference ) {
            $response   .= "'def_home_page':" . ($oper_dets->operator_preference->default_home_page || "0") . ",";
        }
        else {
            $response   .= "'def_home_page':0,";
        }

        $response   .= "'auths':[";
        foreach my $auth ( keys %auths ) {
            $response   .= "{'auth_id':'".$auth."','auth_level':".$auths{$auth}."},";
        }
        $response   =~ s/,$//;
        $response   .= "]}";
    }
    else {
        $response   = '{"status":"ERROR","msg":"Couldn\'t find Operator to Clone"}';
    }

    # write out response
    $handler->{r}->content_type( 'text/plain' );
    $handler->{r}->print( encode_it($response) );

    return OK;
}

1;
