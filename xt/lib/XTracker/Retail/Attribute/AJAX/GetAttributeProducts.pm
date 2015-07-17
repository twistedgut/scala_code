package XTracker::Retail::Attribute::AJAX::GetAttributeProducts;

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

    my $r               = shift;
    my $req             = $r; # they're the same thing in our new Plack world

    my $response        = '';       # response string
    my $product_data    = '';       # result set

    my $attribute_id    = $req->param('attribute_id');  # attribute id from URL
    my $live            = $req->param('live');          # live flag
    my $visible         = $req->param('visible');       # visible flag
    my $channel_id      = $req->param('channel_id');    # sales channel id


    # quick check to make sure the AJAX call didn't pass through 'undefined' as a string
    if ($live eq 'undefined') {
        $live = undef;
    }

    if ($visible eq 'undefined') {
        $visible = undef;
    }

    # get products if required params provided
    if ( $attribute_id && $channel_id ) {

        # get db handle
        my $schema = xtracker_schema;

        # get Category Navigation DB Factory object
        my $factory = XTracker::DB::Factory::ProductAttribute->new({ schema => $schema });

        # start building response JSON data set
        $response = '{"ResultSet":{';
        $response .= '"Result":[';

        # product request
        $product_data = $factory->get_attribute_products(
                                                        {
                                                            'attribute_id'  => $attribute_id,
                                                            'live'          => $live,
                                                            'visible'       => $visible,
                                                            'channel_id'    => $channel_id
                                                        }
                            );

        # loop through children and populate JSON data set
        while (my $root = $product_data->next) {

            my $status;

            if ($root->get_column('live') == 0) {
                $status = 'Non-Live';
            }
            elsif ($root->get_column('visible') == 0) {
                $status = 'Invisible';
            }
            else {
                $status = 'Live';
            }

            # strip out any double quotes from product name
            my $prod_name = $root->get_column('name');
            $prod_name =~ s/\"//g;

            $response .= '{';
            $response .= '"Image":"'.$root->get_column('id').'",';
            $response .= '"PID":"'.$root->get_column('id').'",';
            $response .= '"Name":"'.$prod_name.'",';
            $response .= '"Designer":"'.$root->get_column('designer').'",';
            $response .= '"Colour":"'.$root->get_column('colour').'",';
            $response .= '"Season":"'.$root->get_column('season').'",';
            $response .= '"Price":"'.$root->get_column('price').'",';
            $response .= '"Status":"'.$status.'",';
            $response .= '"Select":"'.$root->get_column('id').'"';
            $response .= '},';

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
