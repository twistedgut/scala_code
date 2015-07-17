/*
 * Bulk Accept orders on Credit Hold
 *
 * Sequential Asynchronous API Calls
 */
$(document).ready(function() {
    $(".tablesorter").tablesorter({
        sortList: [[6,0]],// Default sort on date, asc
        textExtraction: followingColumn,
        headers: {
         // 0: { sorter: true }, // Order No.
            1: { sorter: false }, // hidden Order No
            2: { sorter: false }, // Category
            3: { sorter: false }, // Customer Name
         // 4: { sorter: true  }, // Shipping country
            5: { sorter: false }, // hidden shipping country
         // 6: { sorter: true  }, // date
            7: { sorter: false }, // hidden date column
         // 8: { sorter: true  }, // value
            9: { sorter: false }, // hidden value column
           10: { sorter: false }, // warnings
           11: { sorter: false }, // CV2/AVS
        }
    });

    var qname_release    = 'credithold_accept';
    var qname_rollback   = 'credithold_rollback';
    var process_orders   = true;
    var process_started  = false;
    var bulkorder_id     = 0;
    var pgticker         = null;

    var release_orders_popup__dialog = $('#release_orders_popup').dialog({
        autoOpen : false,
        height   : 110,
        width    : 300,
        draggable: false,
        resizable: false,
        modal    : true,
        open     : function() {
            // HACK: IE8 z-index bug and xtracker dont mix
            $('.ui-widget-overlay').prependTo($('#content')).css({
                position: 'fixed',
                top: 0,
                right: 0
            });
        }
    });

    // HACK: XTracker's crappy CSS requires us to do this
    $('.ui-dialog').prependTo($('#content'));
    $('.ui-dialog-titlebar').remove();


    /*
     * Cancel requested by user
     */
    $('#release_orders_cancel_button').click(function() {
        if (process_started) {
            debug('User: Late cancel request; Rollback');
            process_orders = false;
        }
        else {
            debug('User: Early cancel request; Clearing queues');
            $(document).clearQueue(qname_release);
            $(document).clearQueue(qname_rollback);
            release_orders_popup__dialog.dialog('close');
        }
    });

    /*
     * Start process by user
     */
    $('.release_orders_button').click(function() {
        // get the channel part of the Button's Id
        var button_id_regex = /.*_([A-Z]+)$/;
        var button_id_match = button_id_regex.exec( $(this).attr('id') );
        // then using the channel build the wrapper's Id
        var wrapper_id      = '#release_orders_wrapper_' + button_id_match[1];

        var orders = $(wrapper_id).find('input:checked');
        pgticker   = new ticker(orders.length)

        if (orders.length == 0) {
            alert('No orders selected');
        }
        else {

            $('#progressbar').progressbar({
                value: 0
            });
            $('.pblabel').text('');

            release_orders_popup__dialog.dialog('open');

            // Schedule bulkorderlog call
            add_bulkorderlog_call_to_queue(qname_release, bulk_order_actions.hold_to_accept);
            add_bulkorderlog_call_to_queue(qname_rollback, bulk_order_actions.accept_to_hold);

            // Loop through each order and schedule a call to the API
            jQuery.each(orders, function(idx, order) {
                add_order_to_release_queue(order);
            });

            // Final action in the queue is to relaod the page
            add_reload_page_action_to_queue(qname_release);

            // Start the queue
            $(document).dequeue(qname_release);
        }
    });

    /*
     * Schedule a call to the xTracker to generate an entry in the
     * BulkOrderActionLog table.
     */
    function add_bulkorderlog_call_to_queue(qname, action) {
        $(document).queue(qname, function() {
            debug('BulkOrderActionLog: Start');
            set_dialog_message('Preparing...');

            $.ajax({
                type     : 'GET',
                async    : true,
                url      : '/Finance/CreditHold/BulkOrderActionLog',
                cache    : false,
                dataType : 'json',
                data     : {
                    action_id: action
                },
                error    : function(jqXHR, textStatus, errorThrown) {
                    debug('BulkOrderActionLog: Error '+textStatus);
                },
                success  : function(data, textStatus, jqXHR) {
                    debug('BulkOrderActionLog: ID = '+data.bulk_order_action_log_id);
                    bulkorder_id = data.bulk_order_action_log_id
                    $(document).dequeue(qname);
                }
            });
        });
    }

    /*
     * Schedule a call to xTracker for changing the status of an Order
     */
    function add_order_to_release_queue(order) {

        // Now make the call to xTracker
        $(document).queue(qname_release, function() {
            set_dialog_message('Releasing order #'+$('#'+order.id).val());
            debug('UpdateOrderStatus Release: Start #'+pgticker.value());

            process_started = true;

            update_progress_bar();

            var next_order = function() {
                if (process_orders) {
                    pgticker.increase();
                    debug('UpdateOrderStatus Release: Dequeue next request');
                    $(document).dequeue(qname_release);
                }
                else {
                    debug('UpdateOrderStatus Release: Clear queue');
                    add_reload_page_action_to_queue(qname_rollback);
                    $(document).dequeue(qname_rollback);
                }
            };

            $.ajax({
                type     : 'POST',
                async    : true,
                url      : '/Finance/CreditHold/UpdateOrderStatus',
                cache    : false,
                dataType : 'json',
                // https://metacpan.org/module/Plack::Middleware::CSRFBlock#javascript
                headers :   { "X-CSRF-Token": $("meta[name='csrf_token']").attr("content") },
                data     : {
                    bulk_action_log_id: bulkorder_id,
                    order_id          : order.id,
                    order_status_id   : order_status.accept,
                    action            : 'Accept' // this is need for the ChangeOrderStatus action

                },
                error    : function(jqXHR, textStatus, errorThrown) {
                    debug('UpdateOrderStatus Release: Error '+textStatus);
                    next_order.call();
                },
                success  : function(data, textStatus, jqXHR) {
                    debug('UpdateOrderStatus Release: Success');
                    add_order_to_rollback_queue(order);
                    next_order.call();
                }
            });
        });
    }

    /*
     * Schedule a call to xTracker for changing the status of an Order back to
     * 'Credit Hold'
     */
    function add_order_to_rollback_queue(order) {

        // Now make the call to xTracker
        $(document).queue(qname_rollback, function() {
            var idx = ($(document).queue(qname_rollback).length-1);

            debug('UpdateOrderStatus Rollback: Start #'+pgticker.value());
            set_dialog_message('Reverting order #'+$('#'+order.id).val());

            var next_order = function() {
                pgticker.decrease();
                update_progress_bar();
                $(document).dequeue(qname_rollback);
            }

            $.ajax({
                type        : 'POST',
                async       : true,
                url         : '/Finance/CreditHold/UpdateOrderStatus',
                cache       : false,
                dataType    : 'json',
                // https://metacpan.org/module/Plack::Middleware::CSRFBlock#javascript
                headers :   { "X-CSRF-Token": $("meta[name='csrf_token']").attr("content") },
                data        : {
                    bulk_action_log_id: bulkorder_id,
                    order_id          : order.id,
                    order_status_id   : order_status.credit_hold,
                    action            : 'Hold' // this is need for the ChangeOrderStatus action
                },
                error: function(jqXHR, textStatus, errorThrown) {
                    debug('UpdateOrderStatus Rollback: Error '+textStatus);
                    next_order.call();
                },
                success: function(data, textStatus, jqXHR) {
                    debug('UpdateOrderStatus Rollback: Success');
                    next_order.call();
                }
            });
        });
    }

    /*
     * Final actions after all the calls to xTracker
     */
    function add_reload_page_action_to_queue(queue_name) {
        $(document).queue(queue_name, function() {
            debug('Reloading the page');
            $('#release_orders_cancel_button').hide();
            set_dialog_message('Reloading data...');
            window.location.reload(true);
        });
    }

    function set_dialog_message(txt) {
        $('#release_orders_popup_content').html(txt);
    }

    function update_progress_bar() {
        $('#progressbar').progressbar({
            value: pgticker.percentage()
        });
    }

    function debug(msg) {
        try {
            console.log(msg);
        }
        catch (e) {
            // IE8 does not have a console defined until you open the dev tools
        }
    }
});

/*
 * Simple ticker class
 */
function ticker(size) {
    var total_ticks  = size;
    var current_tick = 1;

    this.increase = function() {
        current_tick++;
        return this;
    }

    this.decrease = function() {
        current_tick--;
        return this;
    }

    this.value = function() {
        return current_tick;
    }

    this.total = function() {
        return total_ticks;
    }

    this.percentage = function() {
        return ((100/total_ticks) * current_tick);
    }

    this.toString =  function() {
        return current_tick+' of '+total_ticks;
    }

    return true;
}

$.tablesorter.addParser({
    id: 'emptyGoesLast',
    is: function(s) { return false },
    format: function(s) {
        if(s == "") {
            return 9999999999;
        }
        return s;
    },
    type: 'numeric'
});

function followingColumn(node) {

    // Find the next node that isn't whitespace
    var n = node;
    do { n = n.nextSibling } while (n && n.nodeType != 1);
    var followingColumn = n;

    if( ! followingColumn ) {
        return "";
    }

    return followingColumn.innerHTML;
}
