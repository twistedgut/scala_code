package XTracker::Schema::ResultSet::Product::AttributeValue;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';


=head2 get_attribute_pids_by_date

returns the rs object of pids that correspond to the attribute_id and the last_upload_date

Essentially:
(this was the initially constructed query using serveral sub selects)
select *  from product.attribute_value where product_id in (select product_id from product_channel where product_id in (select product_id from product.attribute_value where attribute_id = 845 and deleted = false order by sort_order asc ) and upload_date = '2011-03-23 00:00:00') and attribute_id = 845 order by sort_order asc limit 10

(opted to implement this as it's a little easier to read (in dbic and sql))
select pav.product_id, pav.attribute_id, pav.sort_order, pc.upload_date from product.attribute_value as pav
join product_channel as pc on pav.product_id = pc.product_id
where attribute_id = 845 and deleted = false and upload_date = '2011-03-21 00:00:00' order by sort_order asc;

=cut

sub get_attribute_pids_by_date {
    my ( $self, $args ) = @_;

    die "No attribute_id provided" unless defined $args->{ attribute_id };
    die "No upload_date provided" unless defined $args->{ channel_id };

    my $pids_rs = $self->search( {
        'me.attribute_id'             => $args->{ attribute_id },
        'me.deleted'                  => 0,
        'product_channel.upload_date' => $args->{ last_upload_date },
        'product_channel.channel_id'  => $args->{ channel_id },
    },
    {
        join     => 'product_channel',
        order_by => [qw/ sort_order /],
    } );

    return $pids_rs;
}

=head2 latest_upload_date_by_attribute

returns the DateTime object representing the date of the last upload to have occured on a preceeding day for products with a certain attribute value

=cut

sub latest_upload_date_by_attribute {
    my ( $self, $args ) = @_;

    die "No attribute_id provided" unless defined $args->{ attribute_id };
    die "No channel_id provided" unless defined $args->{ channel_id };

    my $inside_rs = $self->search({
      attribute_id => $args->{ attribute_id },
      # deleted      => 0, # so this has been commented out because if an upload hasn't been done in over a week then the sneaky cron script would set the flat for 'this week' to be deleted resulting in this returning nothing (the cron script for reference is script/data_transfer/web_site/populate_whats_new.pl)
    });

    my $upload_dates = $self->result_source->schema->resultset('Public::ProductChannel')->search({
        product_id  => { -in => $inside_rs->get_column('product_id')->as_query },
        channel_id  => $args->{ channel_id },
        live        => 1,
        upload_date => { '!=' => undef },
    },
    {
        select   => 'upload_date',
        group_by => 'upload_date',
        order_by => { -desc => 'upload_date' },
    });

    my $today = DateTime->today();

    # check we have some data to iterate through
    return unless $upload_dates->count() > 0;

    # return the latest upload date unless it's today's date
    while ( my $max_upload_dt = $upload_dates->next->upload_date->truncate( to => 'day') ) {
        return $max_upload_dt unless $max_upload_dt == $today;
    }
    return;
}

1;
