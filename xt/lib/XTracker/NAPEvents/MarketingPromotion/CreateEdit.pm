package XTracker::NAPEvents::MarketingPromotion::CreateEdit;

use NAP::policy "tt";

use XTracker::Handler;
use XTracker::Error;
use XTracker::Navigation            qw( build_sidenav );
use XTracker::Database::Channel     qw( get_channels );
use XTracker::Constants::FromDB     qw( :country );


sub handler {
    my $handler = XTracker::Handler->new( shift );

    my $schema = $handler->schema;
    my $dbh    = $handler->dbh;

    $handler->{data}{yui_enabled}       = 1;

     # load css & javascript for calendar
    $handler->{data}{css}   = ['/yui/calendar/assets/skins/sam/calendar.css','/css/nap_events_in_the_box.css'];
    $handler->{data}{js}    = ['/yui/yahoo-dom-event/yahoo-dom-event.js', '/yui/calendar/calendar-min.js', '/javascript/NapCalendar.js',
                                '/javascript/nap_events_inthebox.js',
                              ];


    $handler->{data}{channels}      = get_channels($dbh);
    $handler->{data}{section}       = 'NAP Events';
    $handler->{data}{subsection}    = 'In The Box';
    $handler->{data}{sidenav}       = build_sidenav( { navtype => 'marketing_promotion' } );

    $handler->{data}{content}       = 'marketing_promotion/create_edit.tt';

    my $action      = $handler->{param_of}{action} // '';
    my $designer_rs = $schema->resultset('Public::Designer');
    my $segment_rs  = $schema->resultset('Public::MarketingCustomerSegment');

    foreach my $channel_id ( keys %{ $handler->{data}{channels} } ) {
        $handler->{data}{designer_list}{ $channel_id }
            = [$designer_rs->list_for_channel( $channel_id )->all];

        $handler->{data}{segment_list}{ $channel_id }
            = $segment_rs->get_enabled_customer_segment_by_channel($channel_id,'t');
    }

    _populate_static_lookup_data( $handler );

    if( $action eq 'edit_promotion' ) {
        #populate form with data
        $handler->{data}{action} = 'Edit';
        my $promotion_rs = $schema->resultset('Public::MarketingPromotion')->find($handler->{param_of}{promotion_id});
        if( $promotion_rs ) {

            # get marketing_promotion details
            $handler->{data}{promotion} = $promotion_rs;
            my $channel_rs = $schema->resultset('Public::Channel')->find($promotion_rs->channel_id);
            $handler->{data}{channel_name} = $channel_rs->name;
            $handler->{data}{sales_channel} = $channel_rs->name;
            $handler->{data}{show_channel} = $promotion_rs->channel_id;
            $handler->{data}{auto_show_channel} = $promotion_rs->channel_id;
            $handler->{data}{channel_obj} = $channel_rs;

            #get log details
            $handler->{data}{promotion_logs} = $promotion_rs->marketing_promotion_logs;

            # get list of Designers for the Sales Channel
            $handler->{data}{designer_list}{ $promotion_rs->channel_id } = [
                $designer_rs->list_for_channel( $promotion_rs->channel_id )
                                ->all
            ];

            $handler->{data}{segment_list}{ $channel_rs->id } = $segment_rs->get_enabled_customer_segment_by_channel($channel_rs->id,'t');

            $handler->{data}{selected_segments}     = [ $promotion_rs->link_marketing_promotion__customer_segments->all ];
            $handler->{data}{segment_list_include}  = join( ',', map { $_->customer_segment_id } @{ $handler->{data}{selected_segments} } );

            _get_options_assigned_to_promotion( $promotion_rs, $handler );
        }
        else {
            xt_warn('Invalid promotion id');
            return $handler->redirect_to('/NAPEvents/InTheBox');
        }

    }
    else {
        $handler->{data}{action} = 'Create';
    }

    return $handler->process_template();
}

sub _populate_static_lookup_data {
    my ( $handler ) = @_;

    # Countries for the weighted dropdown.
    $handler->{data}{static}{countries} = [
        $handler->schema->resultset('Public::Country')
            ->search( {
                id => { '!=' => $COUNTRY__UNKNOWN },
             } )
            ->by_name
            ->all
    ];

    # HS Codes for the weighted dropdown.
    $handler->{data}{static}{hs_codes}  = [
        $handler->schema->resultset('Public::HSCode')
        ->search(
            {
                id      => { '!=' => 0 },
                active  => 1,
                hs_code => [ -and =>
                    { '!=' => '' },
                    { '!=' => undef },
                ],
            },
            {
                order_by => 'hs_code',
            }
        )
        ->all
    ];


    # add the Static Lists that are used to target the Promotion
    # which don't change regardless of the Promotion's Sales Channel

    # for now this will be the same as the 'countries' list above but make this a different list
    # from the U.I. point of view should it be different in the future such as in a different sequence
    $handler->{data}{list}{country}     = $handler->{data}{static}{countries};

    $handler->{data}{list}{language}    = [
        $handler->schema->resultset('Public::Language')->search(
            {},
            {
                order_by    => 'description',
            }
        )->all
    ];

    $handler->{data}{list}{product_type} = [
        $handler->schema->resultset('Public::ProductType')->search(
            {
                id  => { '!=' => 0 },
            },
            {
                order_by => 'product_type',
            }
        )->all
    ];

    $handler->{data}{list}{gender_proxy} = [
        $handler->schema->resultset('Public::MarketingGenderProxy')->search(
            {},
            {
                order_by => 'title',
            }
        )->all
    ];

    $handler->{data}{list}{customer_category} = [
        $handler->schema->resultset('Public::CustomerCategory')->search(
            {},
            {
                order_by => 'category',
            }
        )->all
    ];

    return;
}

# get the Options such as Designer, Country etc. assigned to the Promotion
sub _get_options_assigned_to_promotion {
    my ( $promotion_rec, $handler ) = @_;

    # mapping between the option and it's plural used in calling
    # relationships and methods to get data and populate $handler->{data}
    # also indicates those Options that are channelised and require
    # being built differently on the page
    my %option_list = (
        designer    => { relationship => 'designers', with_channel => 1 },
        country     => { relationship => 'countries' },
        language    => { relationship => 'languages' },
        product_type=> { relationship => 'product_types' },
        gender_proxy=> { relationship => 'gender_proxies', method => 'titles' },
        customer_category => { relationship => 'customer_categories' },
    );

    while ( my ( $option, $value ) = each %option_list ) {
        my $relationship = $value->{relationship};
        my $key          = ( $value->{with_channel} ? 'selected_channel' : 'selected' );

        my $link    = "link_marketing_promotion__${relationship}";
        my $method  = "get_included_" . ( $value->{method} // $relationship );

        my @included_options                            = $promotion_rec->$link->$method->all;
        $handler->{data}{ "${option}_id_list_include" } = join( ',', map { $_->id } @included_options );
        $handler->{data}{ $key }{ $option }             = \@included_options;
    }
}

1;
