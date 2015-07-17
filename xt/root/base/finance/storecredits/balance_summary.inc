
    <div class="formrow divideabove dividebelow">
        <span class="fakelabel">Customer Number:</span>
        <p class="customer_nr">[% customer.pws_customer_id | html %]</p>
    </div>

    <div class="formrow dividebelow">
        <span class="fakelabel">Customer:</span>
        <p class="customer_name">[% customer.display_name | html %]</p>
    </div>

    <div class="formrow dividebelow">
        <span class="fakelabel">Credit:</span>
        <p class="balance">[%
            IF credit;
                credit.balance | format('%.3f') | html; ' '; credit.currency.currency | html;
            ELSE;
                'No store credit';
            END %]</p>
    </div>
