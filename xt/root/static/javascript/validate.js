
function editField( field ){
    var edit = 'edit_' + field.name;
    edit_element = document.getElementById(edit);
    if (! edit_element ) {
        // we don't have any matching elements
        return;
    }
    document.getElementById(edit).value = 'on';
}

function checkForm(theForm) {

    var why = "";
    var fields = theForm.elements;
    var remove = new Array();

    for( var i = 0; i <= fields.length; i++){
    //    alert( fields[i].value );
    //    remove.push( i );
    }

    //why += checkEmail(theForm.email.value);
    //why += checkPhone(theForm.phone.value);
    //why += checkPassword(theForm.password.value);
    //why += checkUsername(theForm.username.value);
    //why += isEmpty(theForm.notempty.value);
    //why += isDifferent(theForm.different.value);

    //why += checkRadio(checkvalue);
    //why += checkDropdown(theForm.choose.selectedIndex);

    if (why != "") {
        alert(why);
        return false;
    }

    return true;
}


function checkUsername (strng) {

    var error = "";
    
    if (strng == "") {
        error = "You didn't enter a username.\n";
    }

    if ((strng.length < 4) || (strng.length > 10)) {
        error = "The username is the wrong length.\n";
    }

    var illegalChars = /\W/;
    
    // allow only letters, numbers, and underscores
    if (illegalChars.test(strng)) {
        error = "The username contains illegal characters.\n";
    } 

     return error;
}
