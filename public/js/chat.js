ffcdata.init = function() {
    var refresh = 60;
    var to;

    /************************************************************************
     *** Standard-Request-Funktion                                        ***
     ************************************************************************/
    var request = function(methd, url, data, callback) {
        try {
            var req = new XMLHttpRequest();
            req.open(methd, url, true);
            req.addEventListener("load", function() {
                if (req.status < 400)
                    callback(JSON.parse(req.responseText));
                else
                    new Error("Request failed: " + req.statusText);
            });
            req.send(data);
            req.addEventListener("error", function() {
                new Error("Network error");
            });
        }
        catch (e) {
            console.log(e);
        }
    };

    /************************************************************************
     *** Empfangene Daten verwerten                                       ***
     ************************************************************************/
    var resolve = function(data) {
        console.log(data);
        t_start();
    };

    /************************************************************************
     *** Timeout handeln                                                  ***
     ************************************************************************/
    var t_stop = function() {
        if ( to ) {
            window.clearTimeout(to);
            console.log('timeout stopped');
        }
    };
    var t_start = function() {
        to = window.setTimeout(ffcdata.receive, refresh * 1000);
        console.log('timeout startet');
    };

    /************************************************************************
     *** Daten abholen                                                    ***
     ************************************************************************/
    ffcdata.receive = function(msg) {
        t_stop();
        var url = ffcdata.unfocusedurl;
        if ( document.hasFocus() )
            url = ffcdata.focusedurl;
        if ( msg ) {
            request('POST', url, 'msg='+JSON.stringify(msg), resolve);
        }
        else {
            request('POST', url, null, resolve);
        }
    };

    /************************************************************************
     *** Refresh-Zeit von aussen ändern                                   ***
     ************************************************************************/
    ffcdata.set_refresh = function(value) {
        var url = ffcdata.refreshseturl.substring(0, ffcdata.refreshseturl.length - 3);
        request('GET', url + value, null, function(res){ 
            if ( res != 'ok' ) {
                new Error('Set refresh time failed');
                console.log('set_refresh error');
            }
            else {
                t_stop();
                refresh = t;
                ffcdata.receive();
                console.log('set_refresh ok');
            }
        });
    };

    /************************************************************************
     *** Titelstring der Webseite ändern                                  ***
     ************************************************************************/
    var set_title = function(newchatcount, newpostcount, newmsgscount) {
        var tp = ffcdata.title;
        var str = tp[0]+newchatcount+tp[1]+newpostcount+tp[2]+newmsgscount+tp[3];
        document.getElementsByTagName("title")[0].firstChild.data = str;
    };

    /************************************************************************
     *** Den Chat verlassen                                               ***
     ************************************************************************/
    window.onbeforeunload = function() {
        request('GET', ffcdata.leaveurl, null, function(ret) { console.log(ret); });
    };

    /************************************************************************
     *** Chatfenster anwählen                                             ***
     ************************************************************************/
    window.onfocus = function() {
        ffcdata.receive();
    };

    /************************************************************************
     *** Fertisch                                                         ***
     ************************************************************************/
    ffcdata.receive();
};

