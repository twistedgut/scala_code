[% IF awaiting_action == 'Putaway';
    param_name = 'process_group_id';
ELSE;
    param_name = 'scan_value';
    scan_field = 'group_id';
END %]
<div id="tabContainer" class="yui-navset">
    [% PROCESS page_elements/channel_tabs.tt channel_list=process_groups,multi_hash=['delivery','quarantine','samples','returns','sample_returns','recodes'] %]
    <div class="yui-content">
        [% channel_count = 1 %]
        [% FOREACH channel = process_groups.keys.sort %]

            <div id="tab[% channel_count %]" class="tabWrapper-[% channel_config.$channel %]">
                <div class="tabInsideWrapper">
                <h3 class='title-[% channel_config.$channel %]'>Process Groups Awaiting [% awaiting_action %]</h3>

                [% IF process_groups.$channel.delivery.size -%]
                <table class="data wide-data divided-data">
                    <thead>
                        <tr>
                            <th>Group</th>
                            <th>Type</th>
                            <th>Delivery</th>
                            <th>PID</th>
                            <th>Designer</th>
                            <th>Delivery Date</th>
                            <th>Upload Date</th>
                            <th>Total</th>
                        </tr>
                    </thead>
                    <tbody>
                        [% FOREACH group_id = process_groups.$channel.delivery.keys.nsort %]
                            [% pg = process_groups.$channel.delivery.$group_id %]

                            [% td_class = '';
                            IF pg.on_hold;
                                td_class = ' class="light"';
                            ELSIF pg.live && pg.type == 'Main';
                                td_class = ' class="warn"';
                            END %]
                            <tr>
                                <td[% td_class %]>
                                    [% IF pg.on_hold %]
                                        [% group_id %] (On Hold)
                                    [% ELSE %]
                                        <a href="[% scan.action %]?[% param_name %]=[% group_id %][% '&scan=Go!&scan_field=' _ scan_field IF scan_field %]">[% group_id %]</a>
                                    [% END %]
                                </td>
                                <td[% td_class %]>[% pg.type %]</td>
                                <td[% td_class %]>[% pg.delivery_id %]</td>
                                <td[% td_class %]>[% pg.product_id || pg.voucher_id %]</td>
                                <td[% td_class %]>[% pg.designer || 'Gift Voucher' %]</td>
                                <td[% td_class %]>[% pg.date %]</td>
                                <td[% td_class %]>
                                    [% IF pg.type == 'Main' %]
                                        [% IF pg.live %]
                                            <span style="font-weight: bold; color:#ff0000">Live</span>
                                        [% ELSE %]
                                            [% '<span style="font-weight: bold; color:#ff0000">' IF pg.priority %]
                                            [% pg.upload_date %]
                                            [% '</span>' IF pg.priority %]
                                        [% END %]
                                    [% ELSE %]
                                        [% pg.upload_date %]
                                    [% END %]
                                </td>
                                <td[% td_class %]>[% pg.quantity %]</td>

                                [% IF scan.action == 'DeliveryCancel/Update' %]
                                    <td><input type='checkbox' name='cancel_[% del.id %]'></td>
                                [% END %]
                            </tr>
                        [% END %]
                    <tbody>
                </table>

                <br><b>Total:</b> [% process_groups.$channel.delivery.size %] process group[% 's' IF process_groups.$channel.delivery.size > 1 %]
                [% END -%]

                [% IF process_groups.$channel.quarantine.size %]
                    <br /><br /><br />

                    <h3 class='title-[% channel_config.$channel %]'>Processed Quarantine Awaiting [% awaiting_action %]</h3>

                    <table class="data wide-data divided-data">
                        <thead>
                            <tr>
                                <th>Group</th>
                                <th>Type</th>
                                <th>Delivery</th>
                                <th>PID</th>
                                <th>Designer</th>
                                <th>Delivery Date</th>
                                <th>Upload Date</th>
                                <th>Total</th>
                            </tr>
                        </thead>
                        <tbody>
                            [% FOREACH group_id = process_groups.$channel.quarantine.keys.nsort %]

                                [% pg = process_groups.$channel.quarantine.$group_id %]

                                [% td_class = '' %]

                                [% IF pg.on_hold %]
                                    [% td_class = ' class="light"' %]
                                [% ELSIF pg.live && pg.type == 'Main' %]
                                    [% td_class = ' class="warn"' %]
                                [% END %]

                                <tr>
                                    <td[% td_class %]>
                                        [% IF pg.on_hold %]
                                            [% pg.group_id %] (On Hold)
                                        [% ELSE %]
                                            <a href="[% scan.action %]?[% param_name %]=[% pg.group_id %][% '&scan=Go!&scan_field=' _ scan_field IF scan_field %]">[% pg.group_id %]</a>
                                        [% END %]
                                    </td>
                                    <td[% td_class %]>[% pg.type %]</td>
                                    <td[% td_class %]>[% pg.delivery_id %]</td>
                                    <td[% td_class %]>[% pg.product_id %]</td>
                                    <td[% td_class %]>[% pg.designer %]</td>
                                    <td[% td_class %]>[% pg.date %]</td>
                                    <td[% td_class %]>
                                        [% IF pg.type == 'Main' %]
                                            [% IF pg.live %]
                                                <span style="font-weight: bold; color:#ff0000">Live</span>
                                            [% ELSE %]
                                                [% IF pg.priority %]<span style="font-weight: bold; color:#ff0000">[% END %]
                                                [% pg.upload_date %]
                                            [% END %]
                                        [% ELSE %]
                                            [% pg.upload_date %]
                                        [% END %]
                                    </td>
                                    <td[% td_class %]>[% pg.quantity %]</td>

                                    [% IF scan.action == 'DeliveryCancel/Update' %]
                                        <td><input type='checkbox' name='cancel_[% del.id %]'></td>
                                    [% END %]
                                </tr>
                            [% END %]
                        <tbody>
                    </table>

                    <br /><b>Total:</b> [% process_groups.$channel.quarantine.size %] process group[% 's' IF process_groups.$channel.quarantine.size > 1 %]
                [% END %]

                [% IF process_groups.$channel.samples.size %]
                    <br /><br /><br />

                    <h3 class='title-[% channel_config.$channel %]'>Vendor Samples Awaiting [% awaiting_action %]</h3>

                    <table class="data wide-data divided-data">
                        <thead>
                            <tr>
                                <th>Group</th>
                                <th>Type</th>
                                <th>Delivery</th>
                                <th>SKU</th>
                                <th>Designer</th>
                                <th>Delivery Date</th>
                                <th>Total</th>
                            </tr>
                        </thead>
                        <tbody>
                        [% FOREACH group_id = process_groups.$channel.samples.keys.nsort %]

                            [% spg = process_groups.$channel.samples.$group_id %]
                            [% IF spg.date_string > 20070826 %]
                                <tr>
                                    <td><a href="[% scan.action %]?[% param_name %]=[% spg.group_id %][% '&scan=Go!&scan_field=' _ scan_field IF scan_field %]">[% spg.group_id %]</a></td>
                                    <td>[% spg.type %]</td>
                                    <td>[% spg.delivery_id %]</td>
                                    <td>[% spg.sku %]</td>
                                    <td>[% spg.designer %]</td>
                                    <td>[% spg.date %]</td>
                                    <td>[% spg.quantity %]</td>
                                </tr>
                            [% END %]
                        [% END %]
                        <tbody>
                    </table>

                    <br><b>Total:</b> [% process_groups.$channel.samples.size %] process group[% 's' IF process_groups.$channel.samples.size > 1 %]

                [% END %]

                [% IF process_groups.$channel.returns.size %]
                    <br /><br /><br />
                    <h3 class='title-[% channel_config.$channel %]'>Customer Returns Awaiting [% awaiting_action %]</h3>

                    <table class="data wide-data divided-data">
                        <thead>
                            <tr>
                                <th>Group</th>
                                <th>Type</th>
                                <th>Delivery</th>
                                <th>SKU</th>
                                <th>Designer</th>
                                <th>Last Action Date</th>
                                <th>RMA</th>
                            </tr>
                        </thead>
                        <tbody>
                        [% FOREACH group_id = process_groups.$channel.returns.keys.nsort %]

                            [% rpg = process_groups.$channel.returns.$group_id %]

                            <tr>
                                <td><a href="[% scan.action %]?[% param_name %]=[% rpg.group_id %][% '&scan=Go!&scan_field=' _ scan_field IF scan_field %]">[% rpg.group_id %]</a></td>
                                <td>[% rpg.type %]</td>
                                <td>[% rpg.delivery_id %]</td>
                                <td>[% rpg.sku %]</td>
                                <td>[% rpg.designer %]</td>
                                <td>[% rpg.date %]</td>
                                <td>[% rpg.rma_number %]</td>
                            </tr>
                        [% END %]
                        <tbody>
                    </table>

                    <br /><b>Total:</b> [% process_groups.$channel.returns.size %] process group[% 's' IF process_groups.$channel.returns.size > 1 %]
                [% END %]

                [% IF process_groups.$channel.sample_returns.size %]
                    <br /><br /><br />
                    <h3 class='title-[% channel_config.$channel %]'>Sample Returns Awaiting [% awaiting_action %]</h3>

                    <table class="data wide-data divided-data">
                        <thead>
                            <tr>
                                <th>Group</th>
                                <th>Type</th>
                                <th>Delivery</th>
                                <th>SKU</th>
                                <th>Designer</th>
                                <th>Last Action Date</th>
                                <th>RMA</th>
                            </tr>
                        </thead>
                        <tbody>
                        [% FOREACH group_id = process_groups.$channel.sample_returns.keys.nsort %]

                            [% rpg = process_groups.$channel.sample_returns.$group_id %]

                            <tr>
                                <td><a href="[% scan.action %]?[% param_name %]=[% rpg.group_id %][% '&scan=Go!&scan_field=' _ scan_field IF scan_field %]">[% rpg.group_id %]</a></td>
                                <td>[% rpg.type %]</td>
                                <td>[% rpg.delivery_id %]</td>
                                <td>[% rpg.sku %]</td>
                                <td>[% rpg.designer %]</td>
                                <td>[% rpg.date %]</td>
                                <td>[% rpg.rma_number %]</td>
                            </tr>
                        [% END %]
                        <tbody>
                    </table>

                    <br /><b>Total:</b> [% process_groups.$channel.sample_returns.size %] process group[% 's' IF process_groups.$channel.sample_returns.size > 1 %]
                [% END %]

                [% IF process_groups.$channel.recodes.size %]
                    <br /><br /><br />
                    <h3 class='title-[% channel_config.$channel %]'>Recodes Awaiting [% awaiting_action %]</h3>

                    <table class="data wide-data divided-data">
                        <thead>
                            <tr>
                                <th>Group</th>
                                <th>Type</th>
                                <th>SKU</th>
                                <th>Designer</th>
                                <th>Quantity</th>
                            </tr>
                        </thead>
                        <tbody>
                        [% FOREACH group_id = process_groups.$channel.recodes.keys.nsort %]

                            [% rpg = process_groups.$channel.recodes.$group_id %]

                            <tr>
                                <td><a href="[% scan.action %]?[% param_name %]=r[% rpg.group_id %][% '&scan=Go!&scan_field=' _ scan_field IF scan_field %]">[% rpg.group_id %]</a></td>
                                <td>[% rpg.type %]</td>
                                <td>[% rpg.sku %]</td>
                                <td>[% rpg.designer %]</td>
                                <td>[% rpg.quantity %]</td>
                            </tr>
                        [% END %]
                        <tbody>
                    </table>

                    <br /><b>Total:</b> [% process_groups.$channel.recodes.size %] process group[% 's' IF process_groups.$channel.recodes.size > 1 %]
                [% END %]
                </div>
            </div>
            [% channel_count = channel_count + 1 %]
        [% END %]
    </div>
</div>

[% PROCESS page_elements/tab_script.tt %]
