package XTracker::Schema::ResultSet::WebContent::Page;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use XTracker::Constants::FromDB qw( :web_content_type );

sub get_page {
    my ( $resultset, $id ) = @_;

    return $resultset->find(
        { 'id' => $id, },
        {
            '+select'  => [qw( type.name template.name )],
            '+as'      => [qw( page_type page_template )],
            'prefetch' => [qw( type template )]
        }
    );
}

sub get_pages_by_type {
    my ( $resultset, $type_id ) = @_;

    my $list = $resultset->search(
        { 'type_id' => $type_id, },
        { 'order_by' => ['id DESC'], },
    );
    return $list;
}

sub get_page_by_name {
    my ( $resultset, $name, $channel_id ) = @_;

    my $page = $resultset->find(
        {
            'name'       => $name,
            'channel_id' => $channel_id
        },
        {
            '+select'  => [ qw( type.name template.name ) ],
            '+as'      => [ qw( page_type page_template ) ],
            'prefetch' => [ qw( type template channel ) ]
        }
    );
    return $page;
}

sub get_cms_pages {
    my ( $resultset, $args ) = @_;

    my $cond;

    # page type specified
    if ( $args->{type_id} ) {
        $cond->{'me.type_id'} = $args->{type_id};
    }
    # no page type specified - just exclude designer landing pages
    else {
        $cond->{'me.type_id'} = { '!=', $WEB_CONTENT_TYPE__DESIGNER_FOCUS };
    }

    my $list = $resultset->search(
        $cond,
        {
            'join'     => [qw( type template )],
            '+select'  => [qw( type.name template.name )],
            '+as'      => [qw( page_type page_template )],
            'prefetch' => [qw( type template )],
            'order_by' => ['me.id DESC']
        }
    );
    return $list;
}

1;
