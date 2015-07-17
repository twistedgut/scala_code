#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

designer_bulk_update.t - Unit test for bulk updating designer details.

=head1 DESCRIPTION

Get a field on the 'Designer Focus' page type to be updated.

Update the contents for the DLPs.

Test only the selected designers were changed in the database.

#TAGS webcontent misc shouldbeunit designer

=cut

use Carp;
use FindBin::libs;

use Data::Dump qw(pp);

use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use XTracker::Config::Local qw( create_cms_page_channels );
use XTracker::Constants qw( :application );
use XTracker::Constants::FromDB qw(:channel :department
                                   :web_content_type
                                   :web_content_field
                                   :web_content_template
                                   :page_instance_status
                                   :designer_website_state
                              );
use Test::XT::BlankDB;


my $schema = Test::XTracker::Data->get_schema;
my $channel = Test::XTracker::Data->get_local_channel(
    create_cms_page_channels()->[0]
);

# Get a field on the 'Designer Focus' page type to be updated
my $field = $schema->resultset('WebContent::Field')
                   ->find($WEB_CONTENT_FIELD__TITLE);

diag 'Updating field ' . $field->name . ', id ' . $field->id;
my $designer_rs = $schema->resultset('Public::Designer')
    ->search({ 'me.designer' => { -not_in => [ qw(None 0) ] } });

my @stuff_to_delete;
END {
    $_->delete() for @stuff_to_delete;
}

# Get a set of designers to be updated (ignore None and 0)
my @designer_ids;
if (Test::XT::BlankDB::check_blank_db($schema)) {
    for my $i (0..5) {
        my $designer = $schema->resultset('Public::Designer')
            ->create({
                designer => "test bulk designer $i",
                url_key => "bulk_$i",
            });
        push @designer_ids,$designer->id
            if @designer_ids < 4;
        my $page = $schema->resultset('WebContent::Page')->create({
            name => "Designer - test bulk designer $i",,
            type_id => $WEB_CONTENT_TYPE__DESIGNER_FOCUS,
            template_id => $WEB_CONTENT_TEMPLATE__STANDARD_DESIGNER_LANDING_PAGE,
            page_key => "bulk_${i}_page",
            channel_id => $channel->id,
        });
        my $instance = $page->create_related('instances',{
            label => "foo$i",
            status_id => $WEB_CONTENT_INSTANCE_STATUS__DRAFT,
            created => DateTime->now(),
            created_by => $APPLICATION_OPERATOR_ID,
            last_updated => DateTime->now(),
            last_updated_by => $APPLICATION_OPERATOR_ID,
        });
        my $content = $instance->create_related('contents',{
            field_id => $WEB_CONTENT_FIELD__TITLE,
            content => "some title $i",
        });
        my $designer_channel = $designer->create_related('designer_channel',{
            page_id => $page->id,
            website_state_id => $DESIGNER_WEBSITE_STATE__INVISIBLE,
            channel_id => $channel->id,
            description => "foo $i",
            description_is_live => 0,
        });
        push @stuff_to_delete,
            $designer_channel,$content,$instance,$page,$designer;
    }
}
else {
    # Get the array of designer ids to be updated
    @designer_ids = $designer_rs->slice(0,4)->get_column('id')->all;
}

# Get the contents for all designers and store them
my $contents = [ $designer_rs->get_contents_for_field({
    field_id   => $field->id,
    channel_id => $channel->id,
})->all ];

# Update the contents
my $field_content = 'created by designer bulk update test';
eval {
    $schema->txn_do(sub{
        # Update the contents for the DLPs
        my $update_designer_rs
            = $designer_rs->search({ 'me.id' => { -in => \@designer_ids } });
        $update_designer_rs->update_field_content({
            field_content => $field_content,
            field_id      => $field->id,
            channel_id    => $channel->id,
            operator_id   => $APPLICATION_OPERATOR_ID,
            environment_override   => 'staging',
        });

        # Test only the selected designers were changed
        foreach my $content ( @{ $contents } ) {
            my $designer = get_designer_by_content($content);
            $content->discard_changes;
            my $designer_id = $designer->id;
            if ( grep { m{^$designer_id$} } @designer_ids ) {
                is( $content->content, $field_content,
                    $designer->designer . ' content updated correctly' );
            }
            else {
                isnt( $content->content, $field_content,
                    $designer->designer . ' content unchanged' );
            }
        }
        die "Rolling back test changes";
    });
};
if ( my $e = $@ ) {
    if ( $e !~ m{Rolling back test changes} ) {
        die "Could not update content: $e";
    }
}

# testing complete
done_testing();

sub get_designer_by_content {
    my ( $content ) = @_;
    croak q{This sub only accepts a XTracker::Schema::Result::WebContent::Content object}
        unless ref $content eq 'XTracker::Schema::Result::WebContent::Content';
    return $content->instance->page->designer_channel->designer;
}
