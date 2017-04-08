"use strict";
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
ffcdata.utils.request = function(methd, url, data, callback, nojson, nojsondata) {
    try {
        // console.log('starting request');
        var req = new XMLHttpRequest();
        req.open(methd, url, true);
        req.addEventListener("load", function() {
            if (req.status < 400) {
                if ( nojson !== undefined && nojson )
                    callback(req.responseText);
                else
                    callback(JSON.parse(req.responseText));
            }
            else
                new Error("Request failed: " + req.statusText);
        });
        req.addEventListener("error", function() {
            new Error("Network error");
        });

        if ( methd === 'POST' ) {
            req.setRequestHeader("Content-type", "multipart/formdata");
            //req.setRequestHeader("Content-length", data.toString().length);
            //req.setRequestHeader("Connection", "close");
            if ( nojsondata ) {
                req.send(data);
            }
            else {
                req.send(JSON.stringify(data));
            }
        }
        else {
            req.send();
        }
    }
    catch (e) {
        console.log('Error on request: ' + e);
    }
};

/************************************************************************
 *** Init für die sonstigen Funktionen                                ***
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

/************************************************************************
 *** Desktopbenachrichtigung absetzen                                 ***
 ************************************************************************/
ffcdata.utils.notify = function(msg){
    if ( Notification.permission !== 'granted' || !ffcdata.notifications )
        return;
    var n = new Notification(msg);
    setTimeout(n.close.bind(n), 5000); 
};

/************************************************************************
 *** Desktopbenachrichtigung einschalten                              ***
 ************************************************************************/
ffcdata.utils.notify_init = function(msg) {
    if ( Notification.permission === 'denied' || Notification.permission === 'granted' )
        return;
    Notification.requestPermission(function(perm){
        if ( perm === 'granted' )
            ffcdata.utils.notify('Benachrichtigungen wurden eingeschalten');
    });
};

