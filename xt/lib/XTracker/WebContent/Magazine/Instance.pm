package XTracker::WebContent::Magazine::Instance;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);
use Data::Dumper;
use Readonly;

use XTracker::Database qw( :common );

use XTracker::DB::Factory::CMS;

use XTracker::Error;
use XTracker::Handler;
use XTracker::Logfile qw( xt_logger );
use XTracker::Session;

sub handler {
    my $handler = XTracker::Handler->new(shift);

        $handler->{data}{content}               = 'webcontent/magazine/instance.tt';
#       $handler->{data}{yui_enabled}   = 1;
        $handler->{data}{section}               = 'Web Content';
        $handler->{data}{subsection}    = 'Magazine';

    # get schema database handle
    my $db_handle = $handler->{schema};

        # check for page id in URL
        if ( $handler->{param_of}{'page_id'} ) {

                $handler->{data}{page_id}       = $handler->{param_of}{'page_id'};

                $handler->{data}{page}  = $db_handle->resultset('WebContent::Page')->get_page( $handler->{data}{page_id} );
                my $channel_info                = $db_handle->resultset('Public::Channel')->get_channel( $handler->{data}{page}->channel_id );

                $handler->{data}{channel_info}  = $channel_info;
                $handler->{data}{sales_channel} = $channel_info->{name};
                $handler->{data}{channel_id}    = $channel_info->{id};

                # Back links for side nav
        push @{ $handler->{data}{sidenav} }, {'None' => [
                                                                                { title => 'Back to Overview', url => '/WebContent/Magazine' },
                                                                                { title => 'Back to Page Details', url => '/WebContent/Magazine/Page?page_id='.$handler->{param_of}{'page_id'} }
                                                                ]};


                # create CMS object
                my $cms_factory = XTracker::DB::Factory::CMS->new({ schema => $db_handle });

                # check for instance id in URL - we're editing an instance
                if ( $handler->{param_of}{'instance_id'} ) {

                        $handler->{data}{page_instance_id}              = $handler->{param_of}{'instance_id'};
                        $handler->{data}{page_instance}                 = $cms_factory->get_instance( $handler->{param_of}{'instance_id'} );
                        $handler->{data}{page_instance_content} = $cms_factory->get_instance_content( $handler->{param_of}{'instance_id'} );

                        if ( $handler->{data}{page_instance}->get_column('status') eq 'Archived' ) {
                                $handler->{data}{subsubsection} = 'Archived Version';
                        }
                        else {
                                $handler->{data}{subsubsection} = 'Edit Version';
                        }

                }
                # otherwise we're creating a new instance
                else {
                        $handler->{data}{subsubsection} = 'Create Version';
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
