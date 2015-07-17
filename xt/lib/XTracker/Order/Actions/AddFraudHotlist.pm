package XTracker::Order::Actions::AddFraudHotlist;

use NAP::policy "tt";
use XTracker::Handler;
use XTracker::Database::Finance;
use XTracker::Utilities qw( url_encode );
use XTracker::Error;
use XTracker::Constants::FromDB qw( :hotlist_field );
use Email::Valid;
use XTracker::Utilities qw(trim);

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new( $r );

    my $redirect    = '/Finance/FraudHotlist';

    my $is_valid = 0;

    if( $handler->{param_of}{field_id} eq $HOTLIST_FIELD__COUNTRY ){
            my $country_obj = $handler->{schema}->resultset("Public::Country");
            if($country_obj->_is_country_valid(trim($handler->{param_of}{value}))){
                    $is_valid = 1;
            }
    }
    else{
        # regular expression checks for one non-space character at the beginning of the string and anything afterwards
        if(trim($handler->{param_of}{value}) =~ m/\A[^\s]+.*\z/){
                    $is_valid = 1;
        }
    }

    if($is_valid){
        eval {
               $handler->{schema}->txn_do( sub {
                   set_hotlist_value(
                       $handler->{schema},
                       {
                           'field_id'      => $handler->{param_of}{field_id},
                           'value'         => trim($handler->{param_of}{value}),
                           'channel_id'    => $handler->{param_of}{channel_id},
                           'order_nr'      => $handler->{param_of}{order_nr},
                       }
                   );
                   xt_success( "Hotlist Entry Added: '" . trim($handler->{param_of}{value}) . "'" );
               } );
           };
   }
   else{
       xt_warn('The value you have entered is not valid');
    }


    if ( my $err = $@ ) {
        if ( $err =~ m/DUPLICATE/ ) {
            xt_warn( "Duplicate - No Hotlist Entry Added for: '" . $handler->{param_of}{value} . "'" );
        }
        else {
            xt_warn( "An error occured whilst trying to add entry to the Hotlist: ${err}" );
        }
    }

    return $handler->redirect_to( $redirect );
}

1;

