package XTracker::Order::Finance::FraudRules::ViewLiveRules;

use NAP::policy "tt";

use XTracker::Navigation qw( build_sidenav );
use XT::FraudRules::JsonData;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    $handler->{data}{content} = 'ordertracker/finance/fraudrules/fraudrules-livepage.tt';

    $handler->{data}{js}      = [
        '/javascript/fraudrules/fraudrules-page.js',
        '/javascript/fraudrules/fraudrules-table.js',
        '/javascript/fraudrules/fraudrules-listitems.js',
        '/javascript/xui.js'
    ];

    $handler->{data}{css} = [
        '/css/jquery.tagit.css',
        '/css/fraudrules/fraudrules-page.css',
        '/css/fraudrules/fraudrules-table.css'
    ];

    $handler->{data}{section}       = 'Finance';
    $handler->{data}{subsection}    = 'Fraud Rules';
    $handler->{data}{subsubsection} = 'Live';

    $handler->{data}{sidenav} = build_sidenav({
        navtype => 'fraud_rules'
    });

    $handler->{data}{rules}     = [$handler->{schema}->resultset('Fraud::LiveRule')->by_sequence];
    $handler->{data}{methods}   = [$handler->{schema}->resultset('Fraud::Method')->get_methods_in_alphabet_order];
    $handler->{data}{channels}  = [$handler->{schema}->resultset('Public::Channel')->all];

    $handler->{data}{change_log}= [
        $handler->schema->resultset('Fraud::ChangeLog')->in_display_order->all ];

    my $action_obj = XT::FraudRules::JsonData->new( {
        schema      => $handler->{schema},
        rule_set    => 'live',
    });
    $handler->{data}{json_data} = $action_obj->build_data;

    return $handler->process_template(undef);
}
