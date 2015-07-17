package XTracker::NAPEvents::MarketingPromotion;

use NAP::policy "tt";

use XTracker::Handler;
use XTracker::Error;
use XTracker::Navigation            qw( build_sidenav );
use XTracker::Database::Channel     qw( get_channels );


sub handler {
    my $handler = XTracker::Handler->new( shift );

    my $schema = $handler->schema;
    my $dbh    = $handler->dbh;


    $handler->{data}{section}       = 'NAP Events';
    $handler->{data}{subsection}    = 'In The Box';
    $handler->{data}{sidenav}       = build_sidenav( { navtype => 'marketing_promotion' } );
    $handler->{data}{content}       = 'marketing_promotion/summary.tt';

    $handler->{data}{css}           = ['/yui/tabview/assets/skins/sam/tabview.css'];
    $handler->{data}{js}            = ['/yui/yahoo-dom-event/yahoo-dom-event.js', '/yui/element/element-min.js', '/yui/tabview/tabview-min.js'];

    $handler->{data}{channels}      = get_channels($dbh);

    foreach my $channel_id (keys % { $handler->{data}{channels}} ) {

        my $channel = $handler->{data}{channels}{$channel_id}{name};
        # get list of marketing_promotions for a channel
        $handler->{data}{promotion}{$channel}{active}   = $schema->resultset('Public::MarketingPromotion')->get_enabled_promotion_by_channel($channel_id);
        $handler->{data}{promotion}{$channel}{disabled} = $schema->resultset('Public::MarketingPromotion')->get_disabled_promotion_by_channel($channel_id);
    }

    return $handler->process_template;
}

1;
