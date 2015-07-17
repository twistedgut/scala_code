#!/opt/xt/xt-perl/bin/perl

use NAP::policy "tt";

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use Mail::Sendmail;

use XTracker::Config::Local 'config_var';
use XTracker::Database 'read_handle';

my $qry = "select max_value - last_value from waybill_nr";
my $waybills_left = read_handle->selectcol_arrayref($qry)->[0];

say $waybills_left;

if ( $waybills_left < 15000 ) {
    send_email($_, "xTracker Waybill Range",
        join qq{\n},
            "\n$waybills_left waybills remaining, please obtain a new range from DHL.",
            q{},
            "Have a nice day,",
            "xTracker\n"
    ) for config_var(qw/Email shipping_email/), 'xtrequests@net-a-porter.com';
}


sub send_email {
    my ($to, $subject, $msg) = @_;

    my %mail = (
        To      => $to,
        From    => 'xtracker@net-a-porter.com',
        Subject => "$subject",
        Message => "$msg",
    );

    print "no mail: $!" unless( sendmail(%mail) )
}
