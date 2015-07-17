#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

use Template;
use HTML::Entities;
use Mail::Sendmail;
use XTracker::Database qw( get_database_handle);;
use XTracker::Comms::DataTransfer   qw(:transfer_handles);
use XTracker::Config::Local qw( config_var );

my $schema = get_database_handle( {
    name => 'xtracker_schema',
} );

my $dbh_fu = get_database_handle( { name => 'Fulcrum', } );
my $qry_fu = $dbh_fu->prepare('
    select pc.product_id, pc.channel_id, pc.visible, p.name, d.name designer_name, l.due upload_date
    from product.product_channel pc, product p, designer d, list.list l 
    where pc.live = true and pc.channel_id = ? 
    and p.id = pc.product_id 
    and d.id = p.designer_id
    and l.id = pc.list_id 
    order by pc.product_id
');

my $dbh_xt = $schema->storage->dbh;
my $qry_xt = $dbh_xt->prepare('select product_id, channel_id, visible from product_channel where product_id = ? and channel_id = ?');

my $vars = {};
$vars->{channels} = [];

my $channel_name;
my $region;

## no critic(ProhibitDeepNests)
foreach my $channel ($schema->resultset('Public::Channel')->all) {
    ($channel_name,$region) = split(/-/,$channel->web_name);
    if ($channel_name ne 'JC') {

        my @data = ();

        my $dbh_wb = get_transfer_sink_handle({ environment => 'live', channel => $channel_name })->{dbh_sink};
        my $qry_wb = $dbh_wb->prepare("select id, date_format(created_dts,'%Y-%m-%d %H:%i') as created_dts, is_visible as visible from searchable_product where id = ?");

        $qry_fu->execute($channel->id);
        while (my $pid_fu = $qry_fu->fetchrow_hashref) { 

            $qry_xt->execute($pid_fu->{product_id},$pid_fu->{channel_id});
            if (my $pid_xt = $qry_xt->fetchrow_hashref) { 

                $qry_wb->execute($pid_xt->{product_id});
                if (my $pid_wb = $qry_wb->fetchrow_hashref) { 
                    $pid_wb->{visible} = $pid_wb->{visible} eq 'T' ? 1 : 0;
                    # (use upload date from web db, which gives us a more accurate datetime)
                    if (($pid_fu->{visible} != $pid_xt->{visible}) || ($pid_fu->{visible} != $pid_wb->{visible})) {
                        push @data, { 
                            product_id => $pid_fu->{product_id},
                            name => $pid_fu->{name},
                            designer_name => $pid_fu->{designer_name},
                            upload_date => $pid_wb->{created_dts},
                            fu_visible => $pid_fu->{visible} ? 'Visible' : 'Invisible',
                            xt_visible => $pid_xt->{visible} ? 'Visible' : 'Invisible',
                            wb_visible => $pid_wb->{visible} ? 'Visible' : 'Invisible',
                            wb_missing => 0,
                        };
                    }

                } else {
                    # unable to find a live pid details on the website (use upload date from list)
                    push @data, { 
                        product_id => $pid_fu->{product_id},
                        name => $pid_fu->{name},
                        designer_name => $pid_fu->{designer_name},
                        upload_date => $pid_fu->{upload_date},
                        fu_visible => $pid_fu->{visible} ? 'Visible' : 'Invisible',
                        xt_visible => $pid_xt->{visible} ? 'Visible' : 'Invisible',
                        wb_visible => '',
                        wb_missing => 1,
                    };
                }
            }
        }

        if (@data) { 
            push @{$vars->{channels}}, {
               name => $channel->name,
               region => $region,
               pids => \@data,
            }
        }

        $qry_wb->finish();
        $dbh_wb->disconnect();
    }
}

my $msg;

if (@{$vars->{channels}}) { 
    my $template = Template->new({ EVAL_PERL => 1 });
    my $tpl = qq~
<head>
<style><!-- td { font-size : 9pt } --></style>
</head>
<body>
<h2>Visibility Discrepancies</h2>
[% FOREACH channel IN channels %]
<h3>[% channel.name %] ([% channel.region %])</h3>
<table border="0" width="100%">
<tr>
    <td><b>PID</b></td>
    <td><b>Name</b></td>
    <td><b>Designer</b></td>
    <td><b>Uploaded</b></td>
    <td><b>Fulcrum</b></td>
    <td><b>XTracker</b></td>
    <td><b>Website</b></td>
</tr>
    [% FOREACH pid IN channel.pids %]
<tr>
    <td>[% pid.product_id %]</td>
    <td>[% pid.name %]</td>
    <td>[% pid.designer_name %]</td>
    <td>[% pid.upload_date %]</td>
    <td>[% pid.fu_visible %]</td>
    <td>[% pid.xt_visible %]</td>
    [% IF pid.wb_missing == 0 %]
    <td>[% pid.wb_visible %]</td>
    [% ELSE %]
    <td><span style='color:#980000'>MISSING</span></td>
    [% END %]
</tr>
    [% END %]
</table>
</body>
[% END %]
~;
    $template->process(\$tpl,$vars,\$msg) or die $template->error();
} else {
    $msg = 'No discrepancies found.';
}

my $send_to = $ARGV[0] || config_var('Email', 'app_support');
my $from    = config_var('Email', 'xtracker_email');

my %mail = (
    'To'       => $send_to,
    'From'     => $from,
    'Reply-To' => $from,
    'Subject'  => 'Fulcrum/XT/Web Visibility Report - ' . $region,
    'content-type' => 'text/html; charset="iso-8859-1"',
    'Message'  => $msg,
);

sendmail(%mail);
