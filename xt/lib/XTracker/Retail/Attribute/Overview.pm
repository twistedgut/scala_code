package XTracker::Retail::Attribute::Overview;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);
use Data::Dumper;
use Readonly;

use XTracker::Handler;
use XTracker::DB::Factory::ProductAttribute;
use XTracker::Error;
use XTracker::Logfile                                                   qw( xt_logger );
use XTracker::Config::Local                                             qw( config_var get_file_paths );

sub handler {
    my $handler = XTracker::Handler->new(shift);

    # get schema database handle
    my $db_handle       = $handler->{schema};

        # get list of channels
        my $channels    = $db_handle->resultset('Public::Channel')->get_channels();


    $handler->{data}{content}           = 'retail/attribute/overview.tt';
    $handler->{data}{yui_enabled}       = 1;
    $handler->{data}{section}           = 'Retail';
        $handler->{data}{subsection}    = 'Attribute Management';
        $handler->{data}{channels}              = $channels;
    $handler->{data}{xt_url}        = config_var('URL', 'url');

        if ( !$handler->{param_of}{channel_id} ) {
                $handler->{param_of}{channel_id}        = $handler->pref_channel_id                                     if ( $handler->pref_channel_id && !exists $handler->{param_of}{change} );
                $handler->{param_of}{channel_id}        = $handler->{data}{auto_show_channel}{id}       if ( defined $handler->{data}{auto_show_channel}{id} && !exists $handler->{param_of}{change} );
        }

        if ( $handler->{param_of}{channel_id} && exists($channels->{ $handler->{param_of}{channel_id} }) ) {

                $handler->{data}{sales_channel}         = $channels->{ $handler->{param_of}{channel_id} }{name};
                $handler->{data}{channel_id}            = $channels->{ $handler->{param_of}{channel_id} }{id};
                $handler->{data}{subsubsection}         = $handler->{data}{sales_channel};
                $handler->{data}{sidenav}                       = [ { 'None' => [{ title => 'Change Channel', url => '/Retail/AttributeManagement?change=1' }] } ];
                # get the relative web path for slug images
                $handler->{data}{channels}{ $handler->{data}{channel_id} }{slug_path}   = get_file_paths( $channels->{ $handler->{data}{channel_id} }{config_section} )->{slug_source};

                $handler->{data}{attribute_type_id}     = $handler->{param_of}{'attribute_type_id'};
                $handler->{data}{attribute_type}        = $handler->{param_of}{'attribute_type'};
                $handler->{data}{attribute_id}          = $handler->{param_of}{'attribute_id'};
                $handler->{data}{attribute_name}        = $handler->{param_of}{'attribute_name'};
                $handler->{data}{attribute_key}         = $handler->{param_of}{'attribute_key'};

                # create Product Attribute object
                my $factory = XTracker::DB::Factory::ProductAttribute->new({ schema => $db_handle });

                # get all non-navigational attribute types
                $handler->{data}{attribute_types} = $factory->get_attribute_types(
                        {
                                #-and => [
                                #                       'name'  => { '!=', 'Classification' },
                                #                       'name'  => { '!=', 'Product Type' },
                                #                       'name'  => { '!=', 'Sub-Type' },
                                #],
                                'navigational' => 0,
                'name' => { '!=', 'Hierarchy' }
                        }
                );

                $handler->{data}{attributes} = $factory->get_attributes( { 'deleted' => 0 } );

        }

    $handler->process_template( undef );
    return OK;
}


1;

__END__
