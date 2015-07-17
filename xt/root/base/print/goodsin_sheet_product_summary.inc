<table width="650" border="2" cellpadding="10" cellspacing="0" bordercolor="#000000" style="border-style:solid">
    <tbody>
        <tr>
            <td><b>Sales Channel:</b> [% sales_channel %]</td>
        </tr>
        [% IF is_voucher %]
        <tr>
            <td><b>Type:</b> Gift Voucher</td>
        </tr>
        [% ELSE %]
        <tr>
            <td><b>Designer:</b> [% product.designer %]</td>
        </tr>
        <tr>
            <td><b>Description:</b> [% product.description %]</td>
        </tr>
        <tr>
            <td><b>Designer Colour:</b> [% product.designer_colour || '-' %] ([% product.designer_colour_code || '-' %])</td>
        </tr>
        <tr>
            <td><b>Style Number:</b> [% product.style_number %]</td>
        </tr>
        <tr>
            <td><b>Storage Type:</b> [% product.storage_type %]</td>
        </tr>
        [% END %]
    </tbody>
</table>
