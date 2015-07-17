
// This module assumes:
//  - a 'pims' variable has been created in scope of type Pims (javascript/Pims.js)
//  - a 'dcCode' variable has been created in scope of type String

        $(function() {
            $("#dialog").dialog({
                autoOpen: false,
                resizable: false,
                width: "auto"
            });
            $(".dialogify").on("click", function(e) {
                e.preventDefault();
                $("#dialog").html("<p>" + $(this).prop("data-box") + "</p>");
                $("#dialog").dialog("option", "position", {
                    my: "center",
                    at: "center",
                    of: window
                });
                if ($("#dialog").dialog("isOpen") == false) {
                    $("#dialog").dialog("open");
                }
            });
        });
