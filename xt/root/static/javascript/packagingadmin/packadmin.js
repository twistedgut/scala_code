
// This module assumes:
//  - a 'pims' variable has been created in scope of type Pims (javascript/Pims.js)
//  - a 'dcCode' variable has been created in scope of type String

// $(document).ready(function(){
//     var selectedDiv=  "";
//     $( "#updateboxdialog" ).dialog({
//           buttons: [
//             {
//               text: "Submit",
//               click: submitBoxQuantityUpdate
//             }
//         ],
//         modal: true,
//         autoOpen: false,
//         minWidth: 700
//     });

//     $("#addpo").click(function() {
//         selectedDiv="#" + this.rel;
//         $(selectedDiv).fadeIn(0500);
//         $(selectedDiv).dialog("open"); });

//     resetTableBoxes()
// });

// function resetTableBoxes() {
//     $("#boxquant").val("");
//     $("#reason").val("Drop down goes here");
//     $("#comment").val("");
//     return;
// }

// function submitBoxQuantityUpdate() {
//     $( this ).dialog( "close" );

//     var incCalls = [];

//     $(".addpobox").each(function() {
//         var boxCode = $(this).attr('id');
//         var amount = $(this).val();
//         if(amount > 0) {
//             incCalls.push(pims.incQuantity(boxCode, amount));
//         }
//     });

//     // Need to wait until the calls to PIMS are complete before reloading the page (else the browser gets very upset)
//     return $.when.apply($, incCalls).done(function() {
//         // Reload the page to ensure that the quantities are up to date (I know, ick right?)
//         location.reload(true);
//     });
// }



// This module assumes:
//  - a 'pims' variable has been created in scope of type Pims (javascript/Pims.js)
//  - a 'dcCode' variable has been created in scope of type String

$(document).ready(function(){
    $( "#addpodialog" ).dialog({
          buttons: [
            {
              text: "Submit",
              click: submitPuchaseOrder
            }
        ],
        modal: true,
        autoOpen: false,
        minWidth: 700
    });

    $("#addpo").click(function() { $('#addpodialog').dialog("open"); });

    resetTableBoxes()
});

function resetTableBoxes() {
    // Kill all the current table rows except the header row
    $("#addpoboxes").find("tr:gt(0)").remove();
    $("#addpopon").val("");

    return pims.loadBoxes().done(setTableBoxes);
}

function submitPuchaseOrder() {
    $( this ).dialog( "close" );

    var incCalls = [];

    $(".addpobox").each(function() {
        var boxCode = $(this).attr('id');
        var amount = $(this).val();
        if(amount > 0) {
            incCalls.push(pims.incQuantity(boxCode, amount));
        }
    });

    // Need to wait until the calls to PIMS are complete before reloading the page (else the browser gets very upset)
    return $.when.apply($, incCalls).done(function() {
        // Reload the page to ensure that the quantities are up to date (I know, ick right?)
        location.reload(true);
    });
}


function setTableBoxes(boxes) {
    for(var x = 0; x < boxes.length; x++) {
        var box = boxes[x];
        if(box.active && box.dcCode == dcCode) {
            $("#addpoboxes").append('<tr><td>' + box.name + ': </td><td><input id="'+ box.code +'" class="addpobox" type="text" /></td></tr>');
        }
    }
}