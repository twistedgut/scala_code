// JavaScript code for picking overview page

// Expand allocation detail
function expandDetail (shipment) {

    // Copy the row with allocations detail below shipment row and show it
    var arow = $('#alloc_row-' + shipment).first();
    var srow = $('#shipment_row-' + shipment).first();
    if ( arow.length >= 1 && srow.length >= 1 ) {
        var newrow = arow.clone();
        newrow.attr('id','shown_alloc_row-' + shipment);
        newrow.attr('class','shown-alloc-detail');
        newrow.insertAfter(srow);
        newrow.show();
    }

    // Set up icon to contract detail
    var icon = $('#expand-' + shipment);
    setContractIcon(icon);
}

// Hide allocation detail
function contractDetail (shipment) {

    // Delete the row with allocations detail
    var row = $('#shown_alloc_row-' + shipment).first();
    if ( row.length >= 1 ) {
        row.remove();
    }

    // Flip the appropriate icon
    var icon = $('#expand-' + shipment);
    setExpandIcon(icon);

    // Add a handler to the icon to close it
    icon.unbind('click');
    icon.click( function () { expandDetail( shipment ); return false; });
}

/* Remove all details from shipment rows and set icons to plus sign */
function hideAllDetail () {

    // Hide the allocation detail cells
    $('.alloc-detail').hide();

    // Delete any cloned allocation detail cells that we're showing
    $('.shown-alloc-detail').remove();

    // Make sure that all the expand icons have a plus sign and the correct handler
    $('.expand-img').each( function (i,o) { setExpandIcon( $(o) ) } );
}

// Set up given icon to be a plus sign and have the expand click handler
function setExpandIcon (icon) {

    // Flip the appropriate icon
    icon.attr( 'src', '/images/plus.gif' );

    // Add a handler to the icon to close it
    icon.unbind('click');
    var shipment = icon.attr('shipment-id');
    icon.click( function () { expandDetail( shipment ); return false; });
}

// Set up given icon to be a plus sign and have the expand click handler
function setContractIcon (icon) {

    // Flip the appropriate icon
    icon.attr( 'src', '/images/minus.gif' );

    // Add a handler to the icon to close it
    icon.unbind('click');
    var shipment = icon.attr('shipment-id');
    icon.click( function () { contractDetail( shipment ); return false; });
}

$(document).ready( function() {

    // Add a click handler to the column headers to hide detail rows when sorting
    $('.colheader').click( function () { hideAllDetail(); return false; } );

    hideAllDetail();

    // Set up custom sort parser for Postgres time intervals
    $.tablesorter.addParser(
         {
             id: 'pginterval',
             is: function(s) { return false; },
             format: function(s) {
                 var nums = s.match(/(\d+)/g)
                 if (nums == null) {
                     return s;
                 }
                 var result = "";
                 if (nums.length == 4) {
                     result = nums.shift();
                 }
                 result += nums.shift() + nums.shift() + nums.shift();
                 if (s.match(/^-/)) {
                     result = "-" + result;
                 }
                 return result;
             },
             type: 'numeric'
         }
    );

    // Set up column sorting
        $(".pickingtable").tablesorter({
                sortList: [[ 6, 0 ]],
                headers: {
                    5: { sorter: false },
                    6: { sorter: 'pginterval' }
                }
        });
});
