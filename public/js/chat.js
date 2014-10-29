ffcdata.init = function() {
    var refresh = 60;
    var to;

    /************************************************************************
     *** Standard-Request-Funktion                                        ***
     ************************************************************************/
    var request = function(methd, url, data, callback) {
        try {
            console.log('starting request');
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
            console.log('Error on request: ' + e);
        }
    };

    /************************************************************************
     *** Titelstring der Webseite ändern                                  ***
     ************************************************************************/
    var set_title = function(newchatcount, newpostcount, newmsgscount) {
        var tp = ffcdata.title;
        var str = tp[0]+newchatcount+tp[1]+newpostcount+tp[2]+newmsgscount+tp[3];
        document.getElementsByTagName("title")[0].firstChild.data = str;
        console.log('title updated');
    };

    /************************************************************************
     *** Refresh-Auswahl aktualisieren                                    ***
     ************************************************************************/
    var update_refreshtime = function(ref) {
        document.getElementById('refreshtime').value = ref;
        console.log('refresh time view updated');
    };

    /************************************************************************
     *** Benutzerliste befüllen                                           ***
     ************************************************************************/
    var update_userlist = function(users) {
        var ul = '';
        for ( var i = 0; i < users.length; i++ ) {
            ul = ul +'<p><span class="username">'
                + users[i][0] + '</span><br /><span class="timestamp">(';
            if ( users[i][2] >= 60 )
                ul = ul + ( users[i][2] / 60 ) + 'min'
            else
                ul = ul + users[i][2] + 'sec';
            ul = ul + ', ' + users[i][1] + ')</span></p>';
            if ( users[i][0] === ffcdata.user )
                update_refreshtime(users[i][2]);
        }
        document.getElementById('userlist').innerHTML = ul;
        console.log('userlist updated');
    };

    /************************************************************************
     *** Neue Chatnachrichten anzeigen                                    ***
     ************************************************************************/
    var add_msgs = function(msgs) {
        var msglog = document.getElementById('msglog');
        var ml = msglog.innerHTML;
        for ( var i = 0; i < msgs.length; i++ ) {
            ml = ml +'<p><span class="username">' + msgs[i][0] + '</span>: ' + msgs[i][1] + '</p>\n';
        }
        msglog.innerHTML = ml;

        var scrollHeight = Math.max(msglog.scrollHeight, msglog.clientHeight);
        msglog.scrollTop = scrollHeight - msglog.clientHeight;

        console.log('new messages added');
    };

    /************************************************************************
     *** Empfangene Daten verwerten                                       ***
     ************************************************************************/
    var resolve = function(data) {
        // Titel aktualisieren
        set_title(data[0].length, data[2], data[3]);

        // Benutzerliste aktualisieren
        update_userlist(data[1]);

        // Neue Nachrichten ins Log schreiben
        add_msgs(data[0]);

        // Timeout wieder neu starten
        t_start();
    };

    /************************************************************************
     *** Timeout handeln                                                  ***
     ************************************************************************/
    var t_stop = function() {
        if ( to ) {
            window.clearTimeout(to);
            console.log('timeout stopped');
            return 1;
        }
        else {
            console.log('no timeout set yet');
            return 0;
        }
    };
    var t_start = function() {
        to = window.setTimeout(ffcdata.receive, refresh * 1000);
        console.log('timeout startet');
    };

    /************************************************************************
     *** Daten abholen                                                    ***
     ************************************************************************/
    var receive = function(msg) {
        if ( t_stop() === 0 ) {
            console.log('timeout allready stopped, receive might be in progress');
            return 0;
        }
        console.log('fetching data');
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
     *** Refresh-Zeit ändern                                              ***
     ************************************************************************/
    var set_refresh = function(value) {
        var url = ffcdata.refreshseturl.substring(0, ffcdata.refreshseturl.length - 3);
        request('GET', url + value, null, function(res){ 
            if ( res != 'ok' ) {
                new Error('Set refresh time failed');
                console.log('set_refresh error');
            }
            else {
                t_stop();
                refresh = t;
                receive();
                console.log('set_refresh ok');
            }
        });
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
        console.log('got focused');
        document.getElementById('msg').focus();
        receive();
    };

    /************************************************************************
     *** Refresh-Einstellung wechseln                                     ***
     ************************************************************************/
    document.getElementById('refreshtime').onchange = function() {
        console.log('refresh time changed');
        set_refresh(this.value);
    };

    /************************************************************************
     *** Manuelles Neuladen                                               ***
     ************************************************************************/
    document.getElementById('reload').onclick = function() {
        console.log('manual reload triggered');
        receive();
    };

    /************************************************************************
     *** Absenden                                                         ***
     ************************************************************************/
    var sendit = function() {
        receive(document.getElementById('msg').value);
    };
    var cleanmsg = function() {
        document.getElementById('msg').value = '';
    }

    /************************************************************************
     *** Manuelles Absenden                                               ***
     ************************************************************************/
    document.getElementById('send').onclick = function() {
        console.log('manual send triggered');
        sendit();
        cleanmsg();
    };

    /************************************************************************
     *** Enter-Absenden                                                   ***
     ************************************************************************/
    document.getElementById('msg').onkeydown = function(e) {
        if ( e.keyCode == 13 && !e.shiftKey && !e.ctrlKey && !e.altKey) {
            console.log('enter-key send triggered');
            sendit();
        }
    };
    document.getElementById('msg').onkeyup = function(e) {
        if ( e.keyCode == 13 && !e.shiftKey && !e.ctrlKey && !e.altKey) {
            console.log('enter-key send done');
            cleanmsg();
        }
    };

    /************************************************************************
     *** Fertisch                                                         ***
     ************************************************************************/
    t_start();
    receive();
    document.getElementById('msg').focus();
};

