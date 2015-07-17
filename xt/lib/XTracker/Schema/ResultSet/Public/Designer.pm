package XTracker::Schema::ResultSet::Public::Designer;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use Carp;

use XTracker::Comms::DataTransfer qw(:transfer_handles);
use base 'DBIx::Class::ResultSet';

use XTracker::Utilities         qw( set_time_to_start_of_day );


sub designer_with_dlp_list {
    my $self = shift;
    my $schema = $self->result_source->schema;


    my @designer_with_dlp = ();

    while (my $designer = $self->next) {
        next unless (my $page = $schema->resultset('WebContent::Page')
            ->search( { name => 'Designer - ' . $designer->designer, } )->first);

        # See if the DLP has an instance
        next unless ($page->instances->search(undef, {order_by => { -desc=>'id'}} )->first);

        push(@designer_with_dlp, $designer);

    }

    return \@designer_with_dlp;

}

=head2 drop_down_options

Returns a resultset of all designers ordered for display in a select drop-down-box.
For now it returns in 'designer' order

=cut

sub drop_down_options {
    my ( $class ) = @_;

    return $class->search({}, { order_by => 'designer' } );
}


sub designer_list {
    my $resultset = shift;

    my $list = $resultset->search( undef,
        {
            order_by => ['designer ASC'],
            cache => 1,
        },
    );

    return $list;
}

=head2 get_contents_for_field
    usage       : $designer_rs->get_contents_for_field({
                    channel_id => $channel_id,
                    field_id   => $field_id,
                  })
    description : Returns the WebContent::Content resultset for designers on a
                  given channel (optional) for a given field_id (optional)
    parameters  : A hashref containing:
                    - the channel_id (optional)
                    - the field_id (optional)
    returns     : A XTracker::Schema::ResultSet::WebContent::Content object
=cut

sub get_contents_for_field {
    my ( $self, $args ) = @_;

    my $designer_channels_params
        = defined $args->{channel_id}
        ? { 'designer_channels.channel_id' => $args->{channel_id} }
        : undef;
    my $contents_params
        = defined $args->{field_id}
        ? { 'contents.field_id' => $args->{field_id} }
        : undef;

    my $rs = $self->related_resultset('designer_channels')
                  ->search( $designer_channels_params )
                  ->related_resultset('page')
                  ->related_resultset('instances')
                  ->related_resultset('contents')
                  ->search( $contents_params );
    return $rs;
}

=head2 update_field_content
    usage       : update_field_content({
                      field_id => $field_id,
                      field_content => $field_content,
                      channel_id => $channel_id,
                      operator_id => $operator_id,
                      [environment_override => 'live',]
                  });
    description : This sub is a wrapper around set_content to allow the bulk
                  update of designers (DCS-2241) in the app.
    parameters  : An hashref containing:
                    - field_id: the id of the web_content.field row for the update
                    - field_conent: the html content for that field
                    - channel_id: the channel_id the designers are on
                    - operator_id: the operator performing the update
                    - environment_override: used to specify if you do not want to update both live and staging [optional]
    returns     : Nothing
=cut

sub update_field_content {
    my ( $self, $args ) = @_;

    my $field_content           = $args->{field_content};
    my $field_id                = $args->{field_id};
    my $channel_id              = $args->{channel_id};
    my $operator_id             = $args->{operator_id};
    my $environment_override    = $args->{environment_override};

    my @environments;
    if($environment_override){
         @environments = ( $environment_override );
    }else{
        @environments = ( qw{live staging} );
    }

    # Pass the schema handle in as the source for the transfer
    my $schema = $self->result_source->schema;

    my $content_rs = $self->get_contents_for_field({
        channel_id => $channel_id,
        field_id   => $field_id,
    });

    my $channel_info = $schema->resultset('Public::Channel')
                              ->get_channel($channel_id);
    # Get web transfer handles
    my $transfer_dbh_ref;
    foreach ( @environments ) {
        $transfer_dbh_ref->{$_} = get_transfer_sink_handle({
            environment => $_,
            channel     => $channel_info->{config_section},
        });
        $transfer_dbh_ref->{$_}{dbh_source} = $schema->storage->dbh;
    };

    my $error_message = q{};
    while (my $content = $content_rs->next ) {
        eval {
            $schema->txn_do(sub {
                $content->set_content({
                    field_content  => $field_content,
#                    category_id    => q{},
                    operator_id    => $operator_id,
                    live_handle    => $transfer_dbh_ref->{live},
                    staging_handle => $transfer_dbh_ref->{staging},
                });
                $transfer_dbh_ref->{$_}{dbh_sink}->commit() for @environments;
            });
        };
        if ( my $e = $@ ) {
            # Rollback website updates on error - XT updates rolled back as part of txn_do
            $transfer_dbh_ref->{$_}{dbh_sink}->rollback() for @environments;
            my $designer_name
                = $content->instance->page->designer_channel->designer->designer;
            $error_message .= "Could not update field for $designer_name: $e";
        }
    }

    # Disconnect web transfer handles
    foreach ( @environments ) {
        $transfer_dbh_ref->{$_}{dbh_sink}->disconnect()
            if $transfer_dbh_ref->{$_}{dbh_sink};
    }
    die "Could not update designers: $error_message"
        if ( length $error_message );
    return;
}

=head2 list_for_upload_date

    $result_set = $self->list_for_upload_date( $channel, $date_time );

Gets a List of Designers for Products for a particular Sales Channel with a particular Upload Date.

=cut

sub list_for_upload_date {
    my ( $self, $channel, $upload_date )    = @_;

    if ( !$channel || ref( $channel ) !~ /::Public::Channel$/ ) {
        croak "No Channel Object has been passed into '" . __PACKAGE__ . "->list_for_upload_date' method";
    }
    if ( !$upload_date || ref( $upload_date ) !~ /DateTime/ ) {
        croak "No DateTime Object has been passed into '" . __PACKAGE__ . "->list_for_upload_date' method";
    }

    # make the date start at the beginning of the day
    my $date    = set_time_to_start_of_day( $upload_date );

    return $self->designer_list     # designer_list sorts by the Designer Name
                   ->search(
                       {
                           'product_channel.channel_id'    => $channel->id,
                           'product_channel.upload_date'   => $date,
                       },
                       {
                           join    => { products => 'product_channel' },
                           distinct=> 1,
                       }
                   );
}

=head2 list_for_channel

    my $result_set  = $self->list_for_channel( $channel_obj or $channel_id );

This will return a list of Designers associated with a Sales Channel using the 'designer_channel' table.

=cut

sub list_for_channel {
    my ( $self, $channel )      = @_;

    if ( !$channel || ( ref( $channel ) !~ /::Public::Channel$/ && $channel !~ /^\d+$/ ) ) {
        croak "No Channel Object or Channel Id has been passed into '" . __PACKAGE__ . "->list_for_channel' method";
    }

    my $channel_id  = ( ref( $channel ) ? $channel->id : $channel );

    return $self->designer_list
                    ->search(
                        {
                            'designer_channel.channel_id'   => $channel_id,
                        },
                        {
                            '+select'   => 'designer_channel.website_state_id',
                            '+as'       => 'website_state_id',
                            join        => 'designer_channel',
                        }
                    );
}

1;
