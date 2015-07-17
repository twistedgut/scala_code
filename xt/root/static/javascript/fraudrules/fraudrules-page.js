var edit_rule_dialog;
var table;
var xlog;
var fraud_rules__loginPopup;
var page_has_submitted_login_request = 0;

$(document).ready(function() {

    table      = new RulesTable(existing_rules);
    xlog       = new xui_logger();

    $('[class^=log_toggle_]').click( function() {
        var id = this.id;
        $('#fraud_rules_log').toggle();
        $('[class^=log_toggle_]').toggle();
    } );

    if (edit_table_mode) {

        edit_rule_dialog = new EditRuleDialog();

        // Alert - if user navigate away without saving
        window.onbeforeunload = function() {
            if($('#fraudscreen__push_to_staging_button').is(":visible") ) {
                return "You have unasaved Data. Save it before you leave the page else you would loose it."
            }
        }

        /*
         * Rules Table
         */

        $("#fraudscreen__ruleset_sequence").sortable({
            revert: true,
            handle: '.fraudscreen__rule_row_handle',
            cursor: "move",
            placeholder: "fraudscreen__rule_row_placeholder",
            stop: function(ev, ui) {
                $('#fraudscreen__push_staging_to_live_button').hide();
                $('#fraudscreen__cancel_changes_button').show();
                $('#fraudscreen__push_to_staging_button').show();
                $('.fraudscreen__force_commit_option').show();
                table.resequenceRules();
            }
        });

        $(table).on('edit', function(event, rule) {
            xlog.debug('Captured RulesTable::Edit event');
            edit_rule_dialog.open(rule);
        });

        /*
         * Page Buttons
         */

        $('#fraudscreen__new_rule_button').click(function() {
            edit_rule_dialog.open();
        });

        $('#fraudscreen__push_live_to_staging_button').click(function() {
            pullFromLiveAction();
        });

        $('#fraudscreen__push_to_staging_button').click(function() {
            saveAction(table.getRuleset());
        });

        $('#fraudscreen__cancel_changes_button').click(function() {
            if (confirm("Are you sure you want to discard these changes?")) {
                $('#fraudscreen__cancel_changes_button').hide();
                $('#fraudscreen__push_to_staging_button').hide();
                $('#fraudscreen__push_staging_to_live_button').show();
                table.resetRules();
            }
        });

        /*
         * Receive Edit Dialog Events
         */

        $(edit_rule_dialog).on('new', function(event, rule) {
            xlog.debug('Captured EditRuleWindow::New event');
            if (!table.isValidRuleName(rule)) {
                alert('Rule name already used. Please use a different name.');
            }
            else {
                edit_rule_dialog.close();
                $('#fraudscreen__push_staging_to_live_button').hide();
                $('#fraudscreen__cancel_changes_button').show();
                $('#fraudscreen__push_to_staging_button').show();
                $('.fraudscreen__force_commit_option').show();
                table.addRule(rule);
            }
        });

        $(edit_rule_dialog).on('saveAsNew', function(event, rule) {
            xlog.debug('Captured EditRuleWindow::SaveAsNew event');
            if (!table.isValidRuleName(rule)) {
                alert('Rule name already used. Please use a different name.');
            }
            else {
                edit_rule_dialog.close();
                $('#fraudscreen__push_staging_to_live_button').hide();
                $('#fraudscreen__cancel_changes_button').show();
                $('#fraudscreen__push_to_staging_button').show();
                $('.fraudscreen__force_commit_option').show();
                table.addRule(rule);
            }
        });

        $(edit_rule_dialog).on('update', function(event, rule) {
            xlog.debug('Captured EditRuleWindow::Update event');
            if (!table.isValidRuleName(rule)) {
                alert('Rule name already used. Please use a different name.');
            }
            else {
                edit_rule_dialog.close();
                $('#fraudscreen__push_staging_to_live_button').hide();
                $('#fraudscreen__cancel_changes_button').show();
                $('#fraudscreen__push_to_staging_button').show();
                $('.fraudscreen__force_commit_option').show();
                table.updateRule(rule);
            }
        });

        $(edit_rule_dialog).on('cancel', function(event, rule) {
            edit_rule_dialog.close();
        });

        $(edit_rule_dialog).on('delete', function(event, rule) {
            xlog.debug('Captured EditRuleWindow::Delete event');
            edit_rule_dialog.close();
            $('#fraudscreen__push_staging_to_live_button').hide();
            $('#fraudscreen__cancel_changes_button').show();
            $('#fraudscreen__push_to_staging_button').show();
            $('.fraudscreen__force_commit_option').show();
            table.deleteRule(rule);
        });
    }

});
