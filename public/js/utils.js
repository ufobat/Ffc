ffcdata.utils = {
    features_disabled: undefined,
};

/************************************************************************
 *** Erweiterte Features auf kleinen Bildschirmen deaktivieren        ***
 ************************************************************************/
ffcdata.utils.is_disabled = function(){
    if ( ffcdata.utils.features_disabled !== undefined )
        return ffcdata.utils.features_disabled;

    if ( window.matchMedia('(max-device-width: 800px)').matches ) 
        ffcdata.utils.features_disabled = true;
    else
        ffcdata.utils.features_disabled = false;

    return ffcdata.utils.features_disabled;
};

/************************************************************************
 *** Standard-Request-Funktion                                        ***
 ************************************************************************/
ffcdata.utils.request = function(methd, url, data, callback) {
    try {
        // console.log('starting request');
        var req = new XMLHttpRequest();
        req.open(methd, url, true);
        req.addEventListener("load", function() {
            if (req.status < 400)
                callback(JSON.parse(req.responseText));
            else
                new Error("Request failed: " + req.statusText);
        });

        if ( methd === 'POST' ) {
            req.setRequestHeader("Content-type", "multipart/formdata");
            //req.setRequestHeader("Content-length", data.toString().length);
            req.setRequestHeader("Connection", "close");
            req.send(JSON.stringify(data));
        }
        else {
            req.send();
        }

        req.addEventListener("error", function() {
            new Error("Network error");
        });
    }
    catch (e) {
        // console.log('Error on request: ' + e);
    }
};

/************************************************************************
 *** Init für die sonstigen Funktioneni                               ***
 ************************************************************************/
ffcdata.utils.init = function(){
    // Browser-Shortcomings ausgleichen
    if ( !document.hasFocus ) {
        document.hasFocus = function() {
            var hfocus = true;
            window.onfocus = function() { hfocus = true;  };
            window.onblur  = function() { hfocus = false; };
            return function() { return hfocus; };
        }();
    }
};

