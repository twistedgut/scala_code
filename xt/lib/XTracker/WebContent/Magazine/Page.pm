package XTracker::WebContent::Magazine::Page;

use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);
use Data::Dumper;
use Readonly;

use XTracker::Error;
use XTracker::Handler;
use XTracker::Logfile               qw( xt_logger );

use XTracker::DB::Factory::CMS;
use XTracker::Utilities             qw( url_encode );

sub handler {
    ## no critic(ProhibitDeepNests)
    my $handler = XTracker::Handler->new(shift);

    $handler->{data}{content}       = 'webcontent/magazine/page.tt';
    $handler->{data}{section}       = 'Web Content';
    $handler->{data}{subsection}    = 'Magazine';
    $handler->{data}{subsubsection} = 'Page';

    # get schema database handle
    my $db_handle = $handler->{schema};

    # create CMS object
    my $cms_factory = XTracker::DB::Factory::CMS->new({ schema => $db_handle });


    # A flag to indicate whether we are creating a brand new page or not
    $handler->{data}{newpage} = 0;

    # back link for side nav
    push @{ $handler->{data}{sidenav} }, {'None' => [ { title => 'Back to Overview', url => '/WebContent/Magazine' } ]};

    CASE: {
        # check for page id in URL
        if ( $handler->{param_of}{'page_id'} ) {

            $handler->{data}{page_id} = $handler->{param_of}{'page_id'};

            last CASE;
        }

        # if searching
        if ( $handler->{param_of}{'searching'} ) {
            # check for page name in URL or page key in URL
            if ( $handler->{param_of}{'page_name'}
              || $handler->{param_of}{'page_key'} ) {

                my %conds;
                my $order_by;

                if ( $handler->{param_of}{'page_name'} ) {
                    $conds{'UPPER(me.name)'}    = { 'like', '%'.uc($handler->{param_of}{'page_name'}).'%' };
                    $order_by                   = "me.name";
                }
                else {
                    my $page_key    = uc($handler->{param_of}{'page_key'});
                    $page_key       =~ s/ /%/g;

                    $conds{'UPPER(me.page_key)'}= { 'like', '%'.$page_key.'%' };
                    $order_by                   = "me.page_key";
                }

                if ( $handler->{param_of}{channel_id} ) {
                    $conds{channel_id}  = $handler->{param_of}{channel_id};
                }

                my @pages   = $db_handle->resultset('WebContent::Page')->search( \%conds, {
                                                                                    '+select'   => [ qw( type.name template.name channel.name ) ],
                                                                                    '+as'       => [ qw( page_type page_template sales_channel ) ],
                                                                                    'prefetch'  => [ qw( type template channel ) ],
                                                                                    'order_by'  => $order_by
                                                                            } );

                # found a page with name provided
                if ( @pages ) {
                    if ( @pages == 1 ) {
                        $handler->{data}{page_id} = $pages[0]->id;
                    }
                    else {
                        # This bit emulates the Overview.pm so as to allow me to use the overview.tt to stick the results in

                        my $channels                = $db_handle->resultset('Public::Channel')->get_channels();
                        $handler->{data}{channels}  = $channels;
                        $handler->{data}{searched}  = 1;

                        $handler->{data}{form_page_name}    = $handler->{param_of}{'page_name'};
                        $handler->{data}{form_page_key}     = $handler->{param_of}{'page_key'};
                        $handler->{data}{form_channel_id}   = $handler->{param_of}{'channel_id'};

                        # little HASH to convert from channel name to channel id in the TT document
                        foreach ( keys %$channels ) {
                            $handler->{data}{channel_ids}{ $channels->{$_}{name} }  = $_;
                        }

                        # build results per sales channel
                        foreach my $page ( @pages ) {
                            push @{ $handler->{data}{search_results}{ $page->channel->name } }, $page;
                        }


                        # Create Page link for side nav
                        if ( $handler->{data}{is_operator} ) {
                            push @{ $handler->{data}{sidenav} }, {'Actions' => [ { title => 'Create New Page', url => '/WebContent/Magazine/Page' } ]};
                        }

                        $handler->{data}{content}   = 'webcontent/magazine/overview.tt';
                        $handler->{data}{css}       = ['/yui/tabview/assets/skins/sam/tabview.css'];
                        $handler->{data}{js}        = ['/yui/yahoo-dom-event/yahoo-dom-event.js', '/yui/element/element-min.js', '/yui/tabview/tabview-min.js'];
                    }
                }
                # nothing found
                else {
                    xt_warn("No Pages Found");
                    return $handler->redirect_to( '/WebContent/Magazine' );
                }
            }
            else {
                xt_warn("No Search Criteria");
                return $handler->redirect_to( '/WebContent/Magazine' );
            }
            last CASE;
        }

        # no page info provided - must be creating new one

        $handler->{data}{newpage}   = 1;
        $handler->{data}{channels}  = $db_handle->resultset('Public::Channel')->get_channels();
    };


    # if we have a page id get the info for that page
    if ( $handler->{data}{page_id} ) {

        # Create Version link for side nav
        if ( $handler->{data}{is_operator} ) {
            push @{ $handler->{data}{sidenav} }, {'Actions' => [ { title => 'Create New Version', url => '/WebContent/Magazine/Instance?page_id='.$handler->{data}{page_id} } ]};
        }

        # get page info
        $handler->{data}{page}              = $handler->{schema}->resultset('WebContent::Page')->get_page( $handler->{data}{page_id} );

        # get all page instances & see what page statues we have for use in TT document
        my $instances                   = $cms_factory->get_page_instances( $handler->{data}{page_id} );
        $handler->{data}{got}{current}  = $instances->count({ status => 'Publish' });
        $handler->{data}{got}{draft}    = $instances->count({ status => 'Draft' });
        $handler->{data}{got}{archive}  = $instances->count({ status => 'Archived' });
        $handler->{data}{instances}     = [ $instances->all ];

        # get publish log
        $handler->{data}{publish_history}   = [ $cms_factory->get_publish_log( $handler->{data}{page_id} ) ];

        my $channel_info    = $db_handle->resultset('Public::Channel')->get_channel( $handler->{data}{page}->channel_id );

        $handler->{data}{channel_info}  = $channel_info;
        $handler->{data}{sales_channel} = $channel_info->{name};
        $handler->{data}{channel_id}    = $channel_info->{id};

    }

    if ( !exists $handler->{data}{searched} ) {
        # get list of page templates and types
        $handler->{data}{page_types}        = $handler->{schema}->resultset('WebContent::Type')->search( undef, { order_by => 'name' });
        $handler->{data}{page_templates}    = $handler->{schema}->resultset('WebContent::Template')->search( undef, { order_by => 'name' });
    }

    $handler->process_template( undef );

    return OK;
}

1;

__END__
