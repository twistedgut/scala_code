// An object for calling the PIMS service, assumes jQuery is in scope


// CONSTRUCTOR
//
// param - url : Where the PIMS instance can be found
function Pims(url) {
  this.url = url;

  // loadBoxes - Calls PIMS for all box data, returns a jQuery XMLHttpRequest object
  this.loadBoxes = function() {
    return $.ajax({
        type: "GET",
        url: this.url + "/box",
        dataType: "json"
    }).fail(function(jqXHR, eMsg, err) {
        alert("Error loading Box data from PIMS: " + eMsg);
    });
  }

  // incQuantity - Calls PIMS to increment the stock of a specific box, returns a jQuery XMLHttpRequest object
  //
  // param - boxCode : Identifer for the box
  // param - amount : How much the stock will be increased
  this.incQuantity = function(boxCode, amount) {
    return $.ajax({
        type: "POST",
        url: this.url + "/quantity/inc/" + boxCode,
        contentType: 'application/json; charset=utf-8',
        data: JSON.stringify({ quantity: amount }),
        dataType: "json"
    }).fail(function(jqXHR, eMsg, err) {
        alert("Error submitting quantity increment to PIMS: " + eMsg);
    });
  }
}