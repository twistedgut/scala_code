#!/opt/xt/xt-perl/bin/perl -I lib
use strict;
use warnings;
use DBI;

my $env_name=shift
    or die "usage: $0 \$envname\n";

# map backend machine to backend db name and frontend db suffix
my %dcs = (
    xtdc1 => ['xtracker','intl'],
    xtdc2 => ['xtracker_dc2','am'],
);

my $web_db='db';

# map frontend channels to order increment
my %web_channels = (
    ice_netaporter => 1,
    out => 10000,
    mrp => 50000,
);

for my $dc (keys %dcs) {

    my $max_order = get_max_order($dc);

    for my $channel (keys %web_channels) {
        set_next_order($dc,$channel,$max_order);
    }

}

sub get_max_order {
    my ($dc) = @_;

    my $db_host = "${dc}-${env_name}.dave";
    my $db_name = $dcs{$dc}->[0];
    my $dbh = DBI->connect(
        "dbi:Pg:dbname=$db_name;host=$db_host",
        'postgres','',
        {
            PrintError=>0,
            RaiseError=>1,
        }
    );

    print "reading from $db_name @ $db_host\n";

    return
        $dbh->selectall_arrayref(
            q{select MAX(CAST(order_nr AS integer)) from orders where order_nr not like '%-%'},
        )->[0][0];
}

sub set_next_order {
    my ($dc,$channel,$base) = @_;

    my $db_name = sprintf '%s_%s',
        $channel,$dcs{$dc}->[1];
    my $db_host = "db-${env_name}.dave";

    print "writing to $db_name @ $db_host\n";

    my $dbh = DBI->connect(
        "dbi:mysql:database=$db_name;host=$db_host",
        'napapp','drag99',
        {
            PrintError=>0,
            RaiseError=>1,
        }
    );

    my $next_order = $base + $web_channels{$channel};

    $dbh->do(qq{alter table orders auto_increment = $next_order});
}
