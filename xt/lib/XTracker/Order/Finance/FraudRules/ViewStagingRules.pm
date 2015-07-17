package XTracker::Order::Finance::FraudRules::ViewStagingRules;

use NAP::policy "tt";

use XTracker::Navigation qw( build_sidenav );
use XTracker::Constants::FromDB qw( :order_status );
use XT::FraudRules::JsonData;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    $handler->{data}{content} = 'ordertracker/finance/fraudrules/fraudrules-stagingpage.tt';

    $handler->{data}{js} = [
        '/javascript/json2.js',
        '/javascript/fraudrules/fraudrules-page.js',
        '/javascript/fraudrules/fraudrules-table.js',
        '/javascript/jquery.tag-it.js',
        '/javascript/fraudrules/fraudrules-editdialog.js',
        '/javascript/fraudrules/fraudrules-savedialog.js',
        '/javascript/fraudrules/fraudrules-actions.js',
        '/javascript/fraudrules/fraudrules-login.js',
        '/javascript/fraudrules/fraudrules-listitems.js',
        '/javascript/xui.js',
    ];

    $handler->{data}{css} = [
        '/css/fraudrules/fraudrules-page.css',
        '/css/fraudrules/fraudrules-table.css',
        '/css/jquery.tagit.css',
        '/css/fraudrules/fraudrules-editdialog.css'
    ];

    $handler->{data}{section}       = 'Finance';
    $handler->{data}{subsection}    = 'Fraud Rules';
    $handler->{data}{subsubsection} = 'Staging';

    $handler->{data}{sidenav} = build_sidenav({
        navtype => 'fraud_rules'
    });

    # Yum Yum, Data
    $handler->{data}{valuetypes} = [$handler->{schema}->resultset('Fraud::ReturnValueType')->all];
    $handler->{data}{methods}    = [$handler->{schema}->resultset('Fraud::Method')->get_methods_in_alphabet_order];
    $handler->{data}{operators}  = [$handler->{schema}->resultset('Fraud::ConditionalOperator')->all];
    $handler->{data}{rules}      = [$handler->{schema}->resultset('Fraud::StagingRule')->by_sequence];
    $handler->{data}{rulestatus} = [$handler->{schema}->resultset('Fraud::RuleStatus')->all];
    $handler->{data}{returntypes} = [$handler->{schema}->resultset('Fraud::ReturnValueType')->all];

    $handler->{data}{channels}   = [$handler->{schema}->resultset('Public::Channel')->all];
    $handler->{data}{actions}    = [
        $handler->{schema}->resultset('Public::OrderStatus')->find($ORDER_STATUS__CREDIT_HOLD),
        $handler->{schema}->resultset('Public::OrderStatus')->find($ORDER_STATUS__ACCEPTED)
    ];

    my $action_obj = XT::FraudRules::JsonData->new( {
        schema      => $handler->{schema},
        rule_set    => 'staging',
    });

    $handler->{data}{json_data} = $action_obj->build_data;

    return $handler->process_template(undef);
}
