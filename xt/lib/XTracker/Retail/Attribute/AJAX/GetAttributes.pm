package XTracker::Retail::Attribute::AJAX::GetAttributes;
use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Database 'xtracker_schema';
use XTracker::DB::Factory::ProductAttribute;

use XTracker::Error;
use XTracker::Handler;
use XTracker::Logfile qw( xt_logger );
use XTracker::DBEncode  qw( encode_it );

sub handler {

    my $r           = shift;
    my $req         = $r; # they're the same thing in our new Plack world
    my $response    = '';       # response string
    my $attr_data   = '';       # result set

    my $type_id     = $req->param('type_id');       # attribute type id
    my $channel_id  = $req->param('channel_id');    # sales channel_id

    # get attributes if type id & channel id provided
    if ( $type_id && $channel_id ){

        # get db handle
        my $schema = xtracker_schema;;

        # get Category Navigation DB Factory object
        my $factory = XTracker::DB::Factory::ProductAttribute->new({ schema => $schema });

        # start building response JSON data set
        $response .= '{"ResultSet":{';
        $response .= '"Result":[';

        $attr_data = $factory->get_attributes( { 'attribute_type_id' => $type_id, 'deleted' => 0, 'channel_id' => $channel_id } );

        # loop through children and populate JSON data set
        while (my $attr = $attr_data->next) {

            my $display_name    = $attr->get_column('name');
            $display_name       =~ s/_/ /g;
            $display_name       =~ s/ and / \& /g;

            $response .= '['.$attr->get_column('id').', "'.$display_name.'", "'.$attr->get_column('name').'", "'.($attr->get_column('synonyms') || '').'", '.$attr->get_column('manual_sort').' ],';
        }

        # strip off the trailing comma
        $response =~ s/,$//;

        # close off response string
        $response .= ']}}';
    }

    # write out response
    $r->content_type( 'text/plain' );
    $r->print( encode_it($response) );

    return OK;
}

1;
