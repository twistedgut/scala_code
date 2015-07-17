package XTracker::WebContent::Magazine::Content;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);
use Data::Dumper;
use Readonly;

use XTracker::Handler;
use XTracker::DB::Factory::CMS;
use XTracker::Error;
use XTracker::Logfile                           qw( xt_logger );

sub handler {
    my $handler = XTracker::Handler->new(shift);

        $handler->{data}{content}               = 'webcontent/magazine/content.tt';
#       $handler->{data}{yui_enabled}   = 1;
        $handler->{data}{section}               = 'Web Content';
        $handler->{data}{subsection}    = 'Magazine';

    # get schema database handle
    my $db_handle       = $handler->{schema};

        # check for page id in URL
        if ( $handler->{param_of}{'page_id'} && $handler->{param_of}{'instance_id'} ) {

                $handler->{data}{page_id}               = $handler->{param_of}{'page_id'};
                $handler->{data}{instance_id}   = $handler->{param_of}{'instance_id'};

                my $page                        = $db_handle->resultset('WebContent::Page')->get_page( $handler->{data}{page_id} );
                my $channel_info        = $db_handle->resultset('Public::Channel')->get_channel( $page->channel_id );

                $handler->{data}{channel_info}  = $channel_info;
                $handler->{data}{sales_channel} = $channel_info->{name};
                $handler->{data}{channel_id}    = $channel_info->{id};

                # Back link for side nav
        push @{ $handler->{data}{sidenav} }, {'None' => [
                                                                                                { title => 'Back to Overview',
                                                                                                        url => '/WebContent/Magazine' },
                                                                                                { title => 'Back to Version Details',
                                                                                                        url => '/WebContent/Magazine/Instance?page_id='.$handler->{param_of}{'page_id'}.'&instance_id='.$handler->{param_of}{'instance_id'} }
                                                                        ]};


                # create CMS object
                my $cms_factory = XTracker::DB::Factory::CMS->new({ schema => $db_handle });

                # check for instance id in URL - we're editing an instance
                if ( $handler->{param_of}{'content_id'} ) {

                        $handler->{data}{content_id}    = $handler->{param_of}{'content_id'};
                        $handler->{data}{page_content}  = $cms_factory->get_content( $handler->{param_of}{'content_id'} );

                        $handler->{data}{subsubsection} = 'Edit Content';

                }
                # otherwise we're creating a new instance
                else {
                        $handler->{data}{subsubsection} = 'Create Content';
                }

                if ( $handler->{data}{is_operator} ) {
                        # get list of content fields
                        $handler->{data}{fields}        = $db_handle->resultset('WebContent::Field')->search( undef, { order_by => 'name' });
                }
                else {
                        if ( $handler->{data}{content_id} ) {
                                # just get the field name if can't edit
                                $handler->{data}{field_name}    = $db_handle->resultset('WebContent::Field')->find( $handler->{data}{page_content}->field_id )->name;
                        }
                }

        }
        # should have a page id otherwise kick back to overview
        else {
                return $handler->redirect_to( "/WebContent/Magazine" );
        }

    $handler->process_template( undef );

    return OK;
}

1;

__END__
