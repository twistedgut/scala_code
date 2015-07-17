package XTracker::WebContent::Magazine::Overview;

use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);
use Data::Dumper;
use Readonly;

use XTracker::Error;
use XTracker::Handler;
use XTracker::Logfile qw( xt_logger );

use XTracker::Constants::FromDB                         qw( :web_content_type );
use XTracker::Config::Local                                     qw( get_cms_config );

sub handler {
    my $handler = XTracker::Handler->new(shift);

        my $channels    = $handler->{schema}->resultset('Public::Channel')->get_channels();

        $handler->{data}{content}               = 'webcontent/magazine/overview.tt';
#       $handler->{data}{yui_enabled}   = 1;
        $handler->{data}{section}               = 'Web Content';
        $handler->{data}{subsection}    = 'Magazine';
        $handler->{data}{channels}              = $channels;
        $handler->{data}{searched}              = 0;

    # get common cms pages to link off overview page
        foreach my $channel_id ( keys %$channels ) {
                my ($channel_name, $channel_config)             = ( $channels->{$channel_id}{name}, $channels->{$channel_id}{config_section} );

                # little HASH to convert from channel name to channel id in the TT document
                $handler->{data}{channel_ids}{ $channel_name }  = $channel_id;

                my $cms_config  = get_cms_config($channel_config);

                foreach my $page ( @{ $cms_config->{common_page} } ) {
                        my $page_result = $handler->{schema}->resultset('WebContent::Page')->get_page_by_name( $page, $channel_id );
                        if ( $page_result ) {
                                push @{ $handler->{data}{common}{ $channel_name } }, $page_result;
                        }
                }
        }

        # Create Page link for side nav
        if ( $handler->{data}{is_operator} ) {
                push @{ $handler->{data}{sidenav} }, {'Actions' => [ { title => 'Create New Page', url => '/WebContent/Magazine/Page' } ]};
        }

        $handler->{data}{css}   = ['/yui/tabview/assets/skins/sam/tabview.css'];
        $handler->{data}{js}    = ['/yui/yahoo-dom-event/yahoo-dom-event.js', '/yui/element/element-min.js', '/yui/tabview/tabview-min.js'];


    $handler->process_template( undef );

    return OK;
}

1;

__END__
