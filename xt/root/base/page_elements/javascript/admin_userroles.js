<script>
    $(document).ready(function() {
        $('#do_not_submit').remove();
        $('#userroles').submit( function(e) {
            if ( $('#newrole').val() ) {
                var aNewRole = $('#newrole').val();
                $('#newroles').append($('<option>', {
                    value: aNewRole,
                    text: aNewRole,
                } ) ).attr('selected', true);
            }
            $('#newroles > option').each( function() {
                $(this).attr('selected', true);
            } );
        } );
        $('#add').click( function() {
            $('#availableroles > option:selected').remove().appendTo('#newroles').attr('selected', true);
        } );
        $('#remove').click( function() {
            $('#newroles > option:selected').remove().appendTo('#availableroles').attr('selected', false);
        } );
    });
</script>

