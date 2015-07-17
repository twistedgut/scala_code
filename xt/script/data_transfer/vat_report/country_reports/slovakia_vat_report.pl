#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;
use lib "/opt/xt/deploy/xtracker/lib";
use FindBin::libs qw( base=lib_dynamic );
use lib "/opt/xt/deploy/xtracker/script/data_transfer/vat_report";

use HTML::HTMLDoc               ();
use XTracker::Database;
use XTracker::PrintFunctions;
use ReportingInvoice;
use Getopt::Long;
use DateTime;

# get list of invoices
my $dbh = read_handle();

my $country = 'Slovakia';

# work out start and end date for the
# last month to pass into query
my $now = DateTime->now;
my $start = $now->truncate( to => 'month' )->subtract( months => 1)->ymd;
my $end = $now->add( months => 1)->ymd;

my $counter = 1;
my $exchange_rate = undef;

GetOptions(
    'exchange_rate=s' => \$exchange_rate,
);

die 'No exchange rate defined' if not defined $exchange_rate;

my $qry1 = "
select r.id, o.order_nr, o.date, sum(ri.unit_price) as total_unit_price,
sum(ri.tax) as total_tax, case when ctr.rate is not null then
round(r.shipping - (r.shipping - (r.shipping / ( 1 + ctr.rate))), 2)
else r.shipping end, round((r.shipping - (r.shipping / ( 1 +
ctr.rate))), 2), rsl.date as invoice_date, cur.currency, r.misc_refund
from renumeration r LEFT JOIN renumeration_item ri ON r.id = ri.renumeration_id, renumeration_status_log rsl, link_orders__shipment los, orders o, shipment s, order_address oa, country c, country_tax_rate ctr, currency cur
where r.renumeration_type_id = 3
and r.renumeration_class_id in (1,4)
and r.id = rsl.renumeration_id
and rsl.renumeration_status_id = 5
and rsl.date between ? and ?
and r.shipment_id = s.id
and s.shipment_address_id = oa.id
and oa.country = ?
and oa.country = c.country
and c.id = ctr.country_id
and r.shipment_id = los.shipment_id
and los.orders_id = o.id
and o.currency_id = cur.id
and o.channel_id = ?
group by r.id, o.order_nr, o.date, r.shipping, ctr.rate, rsl.date,
cur.currency, r.misc_refund
order by o.date asc
";

my $qry2 = "
select r.id, o.order_nr, o.date, sum(ri.unit_price) as total_unit_price,
sum(ri.tax) as total_tax, case when ctr.rate is not null then r.shipping
- (r.shipping * ctr.rate) else r.shipping end, r.shipping * ctr.rate,
rsl.date as invoice_date, cur.currency, r.misc_refund
from renumeration r LEFT JOIN renumeration_item ri ON r.id = ri.renumeration_id, link_orders__shipment los, orders o, shipment s, order_address oa, country c, country_tax_rate ctr, renumeration_status_log rsl, currency cur
where r.renumeration_type_id in (1,2)
and r.renumeration_class_id in (3,4)
and r.id = rsl.renumeration_id
and rsl.renumeration_status_id = 5
and rsl.date between ? and ?
and r.shipment_id = s.id
and s.shipment_address_id = oa.id
and oa.country = ?
and oa.country = c.country
and c.id = ctr.country_id
and r.shipment_id = los.shipment_id
and los.orders_id = o.id
and o.currency_id = cur.id
and o.channel_id = ?
group by r.id, o.order_nr, o.date, r.shipping, ctr.rate, rsl.date,
cur.currency, r.misc_refund
order by o.date asc
";

my %channels = ();

my $ch_qry = "select c.id, b.config_section from channel c, business b where c.business_id = b.id";
my $ch_sth = $dbh->prepare($ch_qry);
$ch_sth->execute();

while( my $row = $ch_sth->fetchrow_hashref() ){
    $channels{ $row->{id} } = $row->{config_section};
}

foreach my $channel_id ( sort {$a <=> $b} keys %channels ) {
    my $invoice_output;
    my $credit_output;
    my $csv_output;

    my $sth = $dbh->prepare($qry1);
    $sth->execute($start, $end, $country, $channel_id);

    while(my $row = $sth->fetchrow_arrayref){

        generate_invoice( $dbh, $exchange_rate, $row->[0], "IT Department", 1 );

        $invoice_output .= "$counter<br />";

        my $source_invoice_filename = XTracker::PrintFunctions::path_for_print_document({
            document_type => 'invoice',
            id => 'VATREPORT-'.$row->[0],
        });
        open (my $IN,'<',$source_invoice_filename) || warn "Cannot open input file: $row->[0]";
        while (my $line = <$IN>) {
            $invoice_output .= $line;
        }
        close($IN);

        $invoice_output .= "<!-- PAGE BREAK -->";

        $csv_output .= "$counter,DEBIT,".$row->[1].','.$row->[7].','.$row->[3].','.$row->[4].','.$row->[5].','.$row->[6].','.$row->[9].','.$row->[8]."\r\n";

        $counter++;
    }

    $sth = $dbh->prepare($qry2);
    $sth->execute($start, $end, $country, $channel_id);

    while(my $row = $sth->fetchrow_arrayref){

        if ($row->[9] > 0 && $row->[9] < 1 ){
                # security credits - ignore
        }
        else {
            generate_invoice( $dbh, $exchange_rate, $row->[0], "IT Department", 1 );

            $credit_output .= "$counter<br />";

            my $source_invoice_filename = XTracker::PrintFunctions::path_for_print_document({
                document_type => 'invoice',
                id => 'VATREPORT-'.$row->[0],
            });
            open (my $IN,'<',$source_invoice_filename) || warn "Cannot open input file: $row->[0]";
            while (my $line = <$IN>) {
                $credit_output .= $line;
            }
            close($IN);

            $credit_output .= "<!-- PAGE BREAK -->";

            $csv_output .= "$counter,CREDIT,".$row->[1].','.$row->[7].','.$row->[3].','.$row->[4].','.$row->[5].','.$row->[6].','.$row->[9].','.$row->[8]."\r\n";

            $counter++;
        }
    }

    open (my $TMP,'>','/opt/xt/deploy/xtracker/script/data_transfer/vat_report/country_reports/temp.html') || warn "Cannot open temp html output file: $!";
    print $TMP $invoice_output;
    close($TMP);

    open (my $TMP2,'>','/opt/xt/deploy/xtracker/script/data_transfer/vat_report/country_reports/temp2.html') || warn "Cannot open temp html output file: $!";
    print $TMP2 $credit_output;
    close($TMP2);

    open (my $CSV,'>','/opt/xt/deploy/xtracker/script/data_transfer/vat_report/output/'.$channels{$channel_id}.'_slovakia_report.csv') || warn "Cannot open csv output file: $!";
    print $CSV "No.,Type,Order Number,Invoice Date,Total Unit Cost,Total Tax,Shipping,Shipping Tax,Misc,Currency\r\n";
    print $CSV $csv_output;
    close($CSV);

    my $doc = HTML::HTMLDoc->new( mode => 'file', tmpdir => '/tmp' );

    $doc->set_output_format('pdf');
    $doc->set_charset('UNICODE');

    $doc->set_input_file('/opt/xt/deploy/xtracker/script/data_transfer/vat_report/country_reports/temp.html');
    $doc->set_header( '.', 'testing', '.' );
    $doc->set_footer( '.', '', '/' );
    $doc->set_right_margin( '0.1', 'in' );
    $doc->set_left_margin( '0.25', 'in' );
    $doc->set_bottom_margin( '0', 'in' );
    $doc->set_top_margin( '0.2', 'in' );
    my $pdf = $doc->generate_pdf();
    $pdf->to_file('/opt/xt/deploy/xtracker/script/data_transfer/vat_report/output/'.$channels{$channel_id}.'_Slovakia_Invoice.pdf') || die("Unable to create file");

    $doc->set_input_file('/opt/xt/deploy/xtracker/script/data_transfer/vat_report/country_reports/temp2.html');
    $doc->set_header( '.', 'testing', '.' );
    $doc->set_footer( '.', '', '/' );
    $doc->set_right_margin( '0.1', 'in' );
    $doc->set_left_margin( '0.25', 'in' );
    $doc->set_bottom_margin( '0', 'in' );
    $doc->set_top_margin( '0.2', 'in' );
    $pdf = $doc->generate_pdf();
    $pdf->to_file('/opt/xt/deploy/xtracker/script/data_transfer/vat_report/output/'.$channels{$channel_id}.'_Slovakia_Credit_Note.pdf') || die("Unable to create file");
}
