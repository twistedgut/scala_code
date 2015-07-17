function toggle_view( section ) {

    var elem = document.getElementById( section );
    var link = document.getElementById("lnk"+section);

    if (elem.style.display=='none' || !elem.style.display){
        elem.style.display = "block";
        if (link.style){
            link.innerHTML="Hide";
        }
    }
    else {
        elem.style.display = "none";
        if (link.style){
            link.innerHTML="View";
        }
    }
}

// Make sure only one marketing option can be selected at a time.
$(document).ready( function() {

    $('#marketing_contact_2month').change( function() {
        if( $(this).prop( 'checked' ) ) {
            $('#marketing_contact_forever').attr( "checked", false );
        }
    });

    $('#marketing_contact_forever').change( function() {
        if( $(this).prop( 'checked' ) ) {
            $('#marketing_contact_2month').attr( "checked", false );
        }
    });

});

