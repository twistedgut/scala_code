#!/opt/xt/xt-perl/bin/perl 
# This script fetches a report for monitoring Premier sms's behaviour and send it to a group of people. 
# It takes the list of comma separated recipients as its first argument and warning-raiser-count (for successfull messages) as its second argument .
# The report displays the total count of all the failures and corresponding failure codes across all the channels. 
# For cases where successful message count is equal to warning-raiser-count, it sends a warning to the recipients provided.
 
use strict;
use warnings;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use Template;
use HTML::Entities;
use Mail::Sendmail;

use XTracker::Database qw( get_database_handle);;
use XTracker::Comms::DataTransfer qw(:transfer_handles);
use XTracker::Config::Local qw( config_var);

use Getopt::Long;
use Data::Dumper;

my $schema = get_database_handle({
       name => 'xtracker_schema',
     });


my $dbh_xt = $schema->storage->dbh;
my $success_total = 0;
my ($name , $total , $status , $failure_code , $email, $count);

my $opts = GetOptions ("email=s" => \$email,"count=i" => \$count);

my $warning_raiser_count = defined ($count) ? $count : 0;
my $subject = 'Premier SMS Service Monitoring Report';
my $msg = "<head><style><!-- td { font-size : 9pt } --></style></head><body><h3>Premier SMS Service Monitoring Report</h3><table width =50%> ";
$msg .= "<tr><td colspan = '3'><b>Channel</b></td><td colspan = '3' ><b>Status</b></td><td colspan = '3' ><b>Count</b></td><td colspan = '3'><b>Failure Code</b></td></tr>";


# Query fetching the status of the premier service sms's across different channels.
my $sms_query = $dbh_xt->prepare("select channel.name,count(mobile_number) as total,status,failure_code from sms_correspondence 
                                left join link_sms_correspondence__shipment on sms_correspondence.id = link_sms_correspondence__shipment.sms_correspondence_id 
                                left join link_sms_correspondence__return on sms_correspondence.id = link_sms_correspondence__return.sms_correspondence_id 
                                left join link_orders__shipment as A on link_sms_correspondence__shipment.shipment_id = A.shipment_id 
                                left join return on link_sms_correspondence__return.return_id = return.id
                                left join link_orders__shipment as B on return.shipment_id = B.shipment_id
                                left join orders as ORDER2 on A.orders_id = ORDER2.id left join orders as ORDER1 on B.orders_id = ORDER1.id,sms_correspondence_status, channel 
                                where sms_correspondence.sms_correspondence_status_id = sms_correspondence_status.id and 
                                      (ORDER1.channel_id = channel.id or ORDER2.channel_id = channel.id) and 
                                      date_sent >= CURRENT_TIMESTAMP - interval '1 day' 
                                      group by channel.name,failure_code,status 
                                      order by channel.name,status desc;");

$sms_query->execute or die $!;
while (my $result = $sms_query->fetchrow_hashref){
   $name = $result->{name};
   $total= $result->{total};
   $status = $result->{status};
   $failure_code = $result->{failure_code};
   $success_total += $total if ($status eq 'Success');
   $failure_code = " " if (not defined $failure_code);
   $msg = $msg."<tr><td colspan = '3'>$name</td>
                 <td colspan = '3'>$status</td>
                 <td colspan = '3'>$total</td>
                 <td colspan = '3'>$failure_code</td>
                </tr>";
}

# Check if any of the channels have succesful messages equal to warning raiser count, raise a warning in mail subject    
my $rows = $sms_query->rows;

if ($rows>0 and $success_total == $warning_raiser_count) {
    $subject = "***WARNING : No Successful Message for Premier SMS Service";
}elsif($rows==0){
    $subject = "No Premier Service SMS";
    $msg = "\n No Records Found \n";
};

$msg = $msg."</body></table>";

#send the report to list of recipients provided
my $send_to = $email;
my $from = "application_support\@net-a-porter.com";
my %mail = (
    'To' => $send_to,
    'From' => $from,
    'Reply-To'=> $from,
    'Subject'=> $subject,
    'content-type' => 'text/html; charset="iso-8859-1"',
    'Message' => $msg,
);

sendmail(%mail);

