#!/opt/xt/xt-perl/bin/perl

=head1 NAME

whm-4232_clean_link_delivery_item__return_item.pl

=head1 DESCRIPTION

clean up link_delivery_item__return_item table by removing duplicate
delivery items for same return items.

We have generalised the data to be removed in 2 categories

category 1: if none of the items have been processed beyond status COUNTED,
then we generate a csv file which will have the delivery items. This will
be a manual process to figure out which delivery items to be deleted

category 2: we figure out the first delivery item with the maximum status
(the one processed to the furthest stage) and just keep that one

=head1 SYNOPSIS

    perl whm-4232_clean_link_delivery_item__return_item.pl

    --help (optional)
    --delete (optional) actual deletion only happens when you use this param,
            else it will just display which items will be deleted
    --export_file (required) complete path of the file which will store
        details of items which have not been processed beyond first stage.
        They need to be looked into and processed manually
=cut

use NAP::policy "tt";
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database 'xtracker_schema';
use XTracker::Constants::FromDB qw(
    :delivery_item_status
);
use Getopt::Long;
use Text::CSV;
use Pod::Usage;

GetOptions ('export_file=s' => \( my $export_file ),
            'delete|?'      => \( my $delete ),
            'help|?'        => \( my $help ))
            or die("Error in command line arguments. Type --help for more options\n");

if ($help || !$export_file) {

    pod2usage(-verbose => 0);
    exit 1;
}

my %remove_delivery_ids;
my $not_removed_deliveries = '/tmp/not_removed_deliveries.csv';

say 'Starting process...';

say ($delete ? "Delivery id's which cannot be deleted for some reason are stored in '$not_removed_deliveries'" : "The items WILL NOT BE DELETED unless delete option is provided. Type --help for options");

my $schema = xtracker_schema;
my $dbh = $schema->storage->dbh;

my $csv = Text::CSV_XS->new({ binary => 1, eol => "\n" })
    or die "Cannot use CSV: ".Text::CSV->error_diag ();

open my $file_handle, '>:encoding(UTF-8)', $export_file
    or die "cant open file $export_file for writing";

my @row = ('Return Item ID', 'Delivery Item ID', 'Delivery ID', 'Status');
$csv->print ($file_handle, \@row);

start_process();

close($file_handle);
$csv->eof or $csv->error_diag();

say '-- Process Complete --';

sub start_process {

    my $sql = qq{
        SELECT return_item_id,
               count(*)
        FROM link_delivery_item__return_item me
        JOIN delivery_item di ON di.id = me.delivery_item_id
        WHERE NOT di.cancel
        GROUP BY return_item_id having count(*) > 1
        ORDER BY count
    };

    my $sth = $dbh->prepare($sql);
    $sth->execute();
    my ($all_rows) = $sth->fetchall_arrayref({});
    $sth->finish;

    foreach my $single_row(@$all_rows) {

        my $duplicate_delivery_items = get_return_item_details($single_row->{return_item_id});
        check_item_status_and_process($duplicate_delivery_items, $single_row->{return_item_id});
    }

    return if (! $delete);

    # remove deliveries which already have all delivery items removed
    # some deliveries will have a valid delivery item, so these wont get
    # deleted because of foreign key constraint (we will store these id's in
    # a file, just for extra info), but the others will be deleted

    open my $deliveries, '>:encoding(UTF-8)', $not_removed_deliveries
        or die "cant open file $not_removed_deliveries for writing";

    my @row = ('Delivery ID', 'Reason not removed');
    $csv->print ($deliveries, \@row);

    foreach my $delivery_id (keys %remove_delivery_ids) {
    say "Deleting delivery: $delivery_id";

        try {
            $sql = qq{delete from delivery
                    where id = $delivery_id};
                    $sth = $dbh->prepare($sql);
                    $sth->execute();
        } catch {
            @row = ($delivery_id, $_);
            $csv->print ($deliveries, \@row);
        };
    }

    close($not_removed_deliveries);
}


sub check_item_status_and_process {

    my ($duplicate_delivery_items, $return_item_id) = @_;

    my $keep_delivery_item  = undef;
    my $keep_delivery_item_status = undef;

    foreach my $single_item(@$duplicate_delivery_items) {

        if (not defined $keep_delivery_item) {
            $keep_delivery_item = $single_item->{delivery_item_id};
            $keep_delivery_item_status = $single_item->{status_id};
        } else {
            if ($single_item->{status_id} > $keep_delivery_item_status) {
                # if this delivery item has been processed further (max status) then keep this
                $keep_delivery_item = $single_item->{delivery_item_id};
                $keep_delivery_item_status = $single_item->{status_id};
            } elsif ($single_item->{delivery_item_id} < $keep_delivery_item
                     && $single_item->{status_id} >= $keep_delivery_item_status) {
                # if this delivery item is first/earliest with maximum status then keep this
                $keep_delivery_item = $single_item->{delivery_item_id};
                $keep_delivery_item_status = $single_item->{status_id};
            }
        }
    }

    if ($keep_delivery_item_status == $DELIVERY_ITEM_STATUS__COUNTED) {
        # case 1: none of the items have been processed to next stage (same status == 2)
        # so we need to create a report which will be used to determine
        # manually which items to be removed
        process_case_1($duplicate_delivery_items);

    } else {
        # case 2: one or more items have been processed to next state
        # keep lowest id(first to be added) with maximum status(maximum processed)
        process_case_2($duplicate_delivery_items, $keep_delivery_item);
    }

}


sub process_case_2 {
    my ($duplicate_delivery_items, $keep_delivery_item) = @_;

    say "Found items which can be removed. Remove batch except delivery item $keep_delivery_item";

    foreach my $single_item(@$duplicate_delivery_items) {
       if ($single_item->{delivery_item_id} != $keep_delivery_item) {
           delete_delivery_item($single_item);
       }
   }
}


sub process_case_1 {
    my ($duplicate_delivery_items) = @_;

    say "Found items which can only be removed manually. Please check export file '$export_file'";

    foreach my $single_item(@$duplicate_delivery_items) {
        my @row = ($single_item->{return_item_id},$single_item->{delivery_item_id},$single_item->{delivery_id},$single_item->{status});
        $csv->print ($file_handle, \@row);
    }
}


sub delete_delivery_item {
    my ($single_item) = @_;

    my $message;
    $message = $delete ? 'Removing' : 'Not removing';
    say "$message ----------- delivery item: $single_item->{delivery_item_id}::delivery: $single_item->{delivery_id}";

    return if (! $delete);

    $remove_delivery_ids{$single_item->{delivery_id}} = 1;

    try {
        $schema->txn_do( sub {

        my ($sql, $sth);

        $sql = qq{delete from link_delivery_item__return_item
                where delivery_item_id = $single_item->{delivery_item_id}};
        $sth = $dbh->prepare($sql);
        $sth->execute();

        $sql = qq{delete from putaway
                where stock_process_id in (select id
                                           from stock_process
                                           where delivery_item_id
                                            = $single_item->{delivery_item_id})};
        $sth = $dbh->prepare($sql);
        $sth->execute();

        $sql = qq{delete from log_putaway_discrepancy
                where stock_process_id in (select id
                                           from stock_process
                                           where delivery_item_id
                                            = $single_item->{delivery_item_id})};
        $sth = $dbh->prepare($sql);
        $sth->execute();

        $sql = qq{delete from rtv_stock_process
                where stock_process_id in (select id
                                           from stock_process
                                           where delivery_item_id
                                            = $single_item->{delivery_item_id})};
        $sth = $dbh->prepare($sql);
        $sth->execute();

        $sql = qq{delete from stock_process
                where delivery_item_id = $single_item->{delivery_item_id}};
        $sth = $dbh->prepare($sql);
        $sth->execute();

        $sql = qq{delete from delivery_item_fault
                where delivery_item_id = $single_item->{delivery_item_id}};
        $sth = $dbh->prepare($sql);
        $sth->execute();

        $sql = qq{delete from rtv_shipment_detail_status_log
                where rtv_shipment_detail_id = (select id
                                                from rtv_shipment_detail
                                                where rma_request_detail_id = (select id
                                                    from rma_request_detail
                                                    where delivery_item_id
                                                        = $single_item->{delivery_item_id}))};
        $sth = $dbh->prepare($sql);
        $sth->execute();

        $sql = qq{delete from rtv_shipment_detail
                where rma_request_detail_id = (select id
                                               from rma_request_detail
                                               where delivery_item_id
                                                = $single_item->{delivery_item_id})};
        $sth = $dbh->prepare($sql);
        $sth->execute();

        $sql = qq{delete from rma_request_detail
                where delivery_item_id = $single_item->{delivery_item_id}};
        $sth = $dbh->prepare($sql);
        $sth->execute();

        $sql = qq{delete from log_delivery
                where delivery_id = $single_item->{delivery_id}};
        $sth = $dbh->prepare($sql);
        $sth->execute();

        $sql = qq{delete from delivery_item
                where id = $single_item->{delivery_item_id}
                and delivery_id = $single_item->{delivery_id}};
        $sth = $dbh->prepare($sql);
        $sth->execute();

        $sql = qq{delete from link_delivery__return
                where delivery_id = $single_item->{delivery_id}};
        $sth = $dbh->prepare($sql);
        $sth->execute();

        $sql = qq{delete from link_delivery__shipment
                where delivery_id = $single_item->{delivery_id}};
        $sth = $dbh->prepare($sql);
        $sth->execute();

        });
    } catch {
        say "Could not delete delivery item $single_item->{delivery_item_id}: $_";
    };
}


sub get_return_item_details {
    my ($return_item_id) = @_;

    my $sql = qq{select ld.delivery_item_id,
                        di.delivery_id,
                        di.status_id,
                        dis.status,
                        ld.return_item_id,
                        sp.id as stock_process_id
                from public.link_delivery_item__return_item ld,
                     delivery_item di,
                     delivery_item_status dis,
                     stock_process sp
                where ld.delivery_item_id = di.id
                and dis.id = di.status_id
                and sp.delivery_item_id = di.id
                and ld.return_item_id = $return_item_id};

    my $sth = $dbh->prepare($sql);
    $sth->execute();
    my ($delivery_items) = $sth->fetchall_arrayref({});
    $sth->finish();

    return $delivery_items;
}
