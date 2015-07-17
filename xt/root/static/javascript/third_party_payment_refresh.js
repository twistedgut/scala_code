$(document).ready(function(){
    var operator_id = $('#operator-id').val();
    var shipment_id = $('#shipment-id').val();
    $('#payment-refresh-button').on('click', function() {
        $.ajax( {
            type: 'POST',
            async: true,
            url: '/CustomerCare/OrderSearch/PaymentRefresh',
            dataType: 'json',
            data: {
                operator_id : operator_id,
                shipment_id : shipment_id
                },
            success :   function(data, textStatus, jqXHR) {
                if (data.on_hold == 1){
                    alert('This shipment is still on hold, press ok to refresh page');
                    location.reload();
                }
                else {
                    alert('This shipment has been released, press ok to go to order view page');
                    var pathname = (location.pathname);
                    var splitPath = pathname.split("/");
                    var newPath = "/" + splitPath[1] + "/" + splitPath[2] + "/OrderView?order_id=" + data.order_id;
                    $(location).attr('href', newPath);
                }
             },
            error   :   function(jqXHR, textStatus, errorThrown) {
                alert('Unable to communicate with XTracker, please try again');
            }
        } );
        return true;
    });
});
