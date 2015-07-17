package XTracker::Database::FlowStatus;
use strict;
use warnings;

use Perl6::Export::Attrs;

use XTracker::Constants::FromDB qw( :flow_status :stock_process_type );

sub flow_status_handled_by_iws :Export(:iws) {
    SMARTMATCH: {
        use experimental 'smartmatch';
        return shift ~~ [
            $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
            $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS,
        ];
    }
}

sub flow_status_from_stock_process_type :Export(:stock_process) {
    my ($stock_process_type,$is_voucher) = @_;

    $is_voucher = '' unless defined $is_voucher;

    SMARTMATCH: {
        use experimental 'smartmatch';
        if ( $stock_process_type ~~ [
            $STOCK_PROCESS_TYPE__RTV,
            $STOCK_PROCESS_TYPE__RTV_NON_DASH_FAULTY,
            $STOCK_PROCESS_TYPE__RTV_CUSTOMER_REPAIR
        ] ) {
            return $FLOW_STATUS__RTV_PROCESS__STOCK_STATUS;
        }
        elsif ($stock_process_type == $STOCK_PROCESS_TYPE__DEAD) {
            return $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS;
        }
        elsif ($stock_process_type == $STOCK_PROCESS_TYPE__FAULTY) {
            return ($is_voucher
                ? $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS
                : $FLOW_STATUS__RTV_GOODS_IN__STOCK_STATUS);
        }
        else {
            return $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS;
        }
    }
}

sub flow_status_handled_by_prl :Export(:prl) {
    SMARTHMATCH: {
        use experimental 'smartmatch';
        return shift ~~ [
            $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
            $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS,
        ];
    }
}

1;
