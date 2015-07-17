package XTracker::Order::Functions::Return::ReverseItem;
use NAP::policy "tt";

use XTracker::Handler;
use XTracker::Error;
use XTracker::Utilities qw( parse_url );
use URI;

### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {

    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # get section and sub-section out of URL
    my ($section, $subsection, $short_url) = parse_url($r);

    $handler->{data}{section}       = $section;
    $handler->{data}{subsection}    = $subsection;
    $handler->{data}{subsubsection} = 'Reverse Return Item';
    $handler->{data}{content}       = 'ordertracker/returns/reverseitem.tt';
    $handler->{data}{short_url}     = $short_url;
    $handler->{data}{return_id}     = $handler->{param_of}{return_id};

    my $return;
    if ($handler->{data}{return_id}) {
        $return = $handler->schema->resultset('Public::Return')->find($handler->{data}{return_id});
        xt_warn('No return could be found with id: ' . $handler->{data}{return_id})
            unless $return;
    } else {
        xt_warn('A return id is required');
    }

    if ($return) {

        my @return_items = $return->return_items()->search(undef, {
            # Lots of deep prefetching to ensure Template toolkit doesn't have to
            # make billions of db calls.
            # If we didn't do this, it would make Phill sad :(
            prefetch => [
                { 'shipment_item' => { 'variant' => [
                    { 'product' => [
                        { 'product_attribute' => 'size_scheme' },
                        'designer',
                    ]},
                    'designer_size',
                    'size',
                ]}},
            ],
        });
        $handler->{data}{return_items} = \@return_items;

        # set sales channel
        $handler->{data}{sales_channel}     = $handler->{data}{order}{sales_channel};

        my $back_to_return_url = URI->new("$short_url/Returns/View");
        $back_to_return_url->query_form({
            return_id   => $return->id(),
            shipment_id => $return->shipment_id(),
            order_id    => $return->shipment()->order()->id(),
        });

        # back link in left nav
        # TODO: Nasty poking around in Handler's guts! Must be a cleaner way(?)
        push(@{ $handler->{data}{sidenav}[0]{'None'} }, {
            'title' => 'Back to Return',
            'url'   => $back_to_return_url->as_string(),
        });
    }

    return $handler->process_template( undef );
}

1;
