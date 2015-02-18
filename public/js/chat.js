"use strict";
/************************************************************************
 *** Initialisierung mit allen notwendigen Funktionen                 ***
 ************************************************************************/
ffcdata.chat = {};

ffcdata.chat.init = function() {
    var refresh = 60;
    var to;
    var history_list = new Array();
    var history_pointer = 0;
    var newchatcountsum = 0;


    /************************************************************************
     *** Chat-Text formatieren                                            ***
     ************************************************************************/
    var textfilter = function(txt) {
        txt = txt.replace(/\\/g, '\\\\');
        txt = txt.replace(/</g, '&lt;');
        txt = txt.replace(/>/g, '&gt;');
        txt = txt.replace(/"/g, '&quot;');
        if ( txt.match(/^\/code\s+/) ) {
            txt = txt.replace(/^\/code\s+/, '');
            txt = '<pre>' + txt + '</pre>';
        }
        else {
            txt = txt.replace(/(([\(|\s])?|^)(https?:\/\/[^\)\s]+?)(\)|,?\s|$)/g, '$1<a href="$3" target="_blank" title="Externe Webadresse! ($3)">$3</a>$4');
            txt = txt.replace(/\n/g, '<br />');
            txt = txt.replace(ffcdata.userre, '<span class="myself">$1</span>');
        }
        return(txt);
    }

    /************************************************************************
     *** Titelstring der Webseite aendern                                 ***
     ************************************************************************/
    var set_title = function(newchatcount, newpostcount, newmsgscount) {
        var tp = ffcdata.title;
        if ( document.hasFocus() )
            newchatcountsum = 0;
        else 
            newchatcountsum = newchatcountsum + newchatcount;
        var str = tp[0]+newchatcountsum+tp[1]+(newpostcount+newmsgscount)+tp[2];
        document.getElementsByTagName("title")[0].firstChild.data = str;
        // console.log('title updated');
    };

    /************************************************************************
     *** Refresh-Auswahl aktualisieren                                    ***
     ************************************************************************/
    var update_refreshtime = function(ref) {
        document.getElementById('refreshtime').value = ref;
        refresh = ref;
        // console.log('refresh time view updated: '+ref);
    };

    /************************************************************************
     *** Benutzerliste befuellen                                          ***
     ************************************************************************/
    var update_userlist = function(users) {
        var ul = '';
        for ( var i = 0; i < users.length; i++ ) {
            ul = ul +'<p><span class="username">'
                + users[i][0] + '</span><br /><span class="timestamp">(';
            if ( users[i][2] >= 60 )
                ul = ul + ( users[i][2] / 60 ) + 'min';
            else
                ul = ul + users[i][2] + 'sec';
            ul = ul + ', ' + users[i][1] + ')</span></p>';
            if ( users[i][0] === ffcdata.user )
                update_refreshtime(users[i][2]);
        }
        document.getElementById('userlist').innerHTML = ul;
        // console.log('userlist updated');
    };

    /************************************************************************
     *** Neue Chatnachrichten anzeigen                                    ***
     ************************************************************************/
    var add_msgs = function(msgs) {
        if ( msgs.length > 0 ) {
            var msglog = document.getElementById('msglog');
            var ml = msglog.innerHTML;
            var userstr = '';
            for ( var i = msgs.length - 1; i >= 0; i-- ) {
                if ( msgs[i][2].match(/^\/me\s+/ ) ) {
                    msgs[i][2] = msgs[i][2].replace(/^\/me\s+/, '');
                    userstr = msgs[i][1] + ' ';
                }
                else {
                    userstr = '<span class="username">' + msgs[i][1] + '</span>: ';
                }
                ml = ml
                   +'<p' + (ffcdata.user === msgs[i][1] ? ' class="ownmsg"' : '') 
                   + '><span class="timestamp">(' + msgs[i][3] + ')</span> '
                   + userstr + textfilter(msgs[i][2]) + '</p>\n';
            }
            msglog.innerHTML = ml;

            var scrollHeight = Math.max(msglog.scrollHeight, msglog.clientHeight);
            msglog.scrollTop = scrollHeight - msglog.clientHeight;

            // console.log('new messages added');
        }
    };

    /************************************************************************
     *** Empfangene Daten verwerten                                       ***
     ************************************************************************/
    var resolve = function(data) {
        // console.log('resolving fetched data');
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
            // console.log('timeout stopped');
            return true;
        }
        else {
            // console.log('no timeout set yet');
            return false;
        }
    };
    var t_start = function() {
        to = window.setTimeout(receive, refresh * 1000);
        // console.log('timeout startet: '+refresh);
    };

    /************************************************************************
     *** Daten abholen                                                    ***
     ************************************************************************/
    var receive = function(msg) {
        // console.log('receiving');
        if ( !t_stop() ) {
            // console.log('timeout allready stopped, receive might be in progress');
            return;
        }
        // console.log('fetching data');
        var url = ffcdata.unfocusedurl;
        if ( document.hasFocus() )
            url = ffcdata.focusedurl;
        if ( msg )
            ffcdata.utils.request('POST', url, msg, resolve);
        else
            ffcdata.utils.request('GET', url, null, resolve);
    };

    /************************************************************************
     *** Refresh-Zeit aendern                                             ***
     ************************************************************************/
    var set_refresh = function(value) {
        var url = ffcdata.refreshseturl.substring(0, ffcdata.refreshseturl.length - 2);
        ffcdata.utils.request('GET', url + value, null, function(res){ 
            if ( res != 'ok' ) {
                new Error('Set refresh time failed');
                // console.log('set_refresh error');
            }
            else {
                receive();
                // console.log('set_refresh ok');
            }
        });
    };

    /************************************************************************
     *** Den Chat verlassen                                               ***
     ************************************************************************/
    window.onbeforeunload = function() {
        ffcdata.utils.request('GET', ffcdata.leaveurl, null, function(ret) { console.log(ret); });
    };

    /************************************************************************
     *** Chatfenster anwaehlen                                            ***
     ************************************************************************/
    window.onfocus = function() {
        // console.log('got focused');
        document.getElementById('msg').focus();
        receive();
    };

    /************************************************************************
     *** Refresh-Einstellung wechseln                                     ***
     ************************************************************************/
    document.getElementById('refreshtime').onchange = function() {
        // console.log('refresh time changed');
        set_refresh(this.value);
    };

    /************************************************************************
     *** Manuelles Neuladen                                               ***
     ************************************************************************/
    document.getElementById('reload').onclick = function() {
        // console.log('manual reload triggered');
        receive();
    };

    /************************************************************************
     *** Message-Log leeren                                               ***
     ************************************************************************/
    var clrscr = function() {
        document.getElementById('msglog').innerHTML = '';
    };
    document.getElementById('clrscr').onclick = function(e) {
        // console.log('clear message log');
        clrscr();
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
        // console.log('manual send triggered');
        sendit();
        cleanmsg();
    };

    /************************************************************************
     *** Enter-Absenden                                                   ***
     ************************************************************************/
    var isShift = false;
    document.getElementById('msg').onkeydown = function(e) {
        if ( e.keyCode == 16 ) {
            isShift = true;
        }

        if ( e.keyCode == 13 && !isShift ) {
            // console.log('enter-key send triggered');
            var msg = document.getElementById('msg');
            var msgval = msg.value;
            if ( msgval ) {
                history_list.push(msgval);
                history_pointer = history_list.length;
            }
            sendit();
        }
    };
    document.getElementById('msg').onkeyup = function(e) {
        if ( e.keyCode == 16 ) {
            isShift = false;
        }

        if ( e.keyCode == 13 && !isShift  ) {
            // console.log('enter-key send done');
            cleanmsg();
        }

        if ( isShift && e.keyCode == 38 && history_pointer > 0 ) { // shift + up arrow, history back
            var msg = document.getElementById('msg');
            var msgval = msg.value;
            if ( msgval.length > 0 && history_list[history_pointer] != msgval ) {
                history_list[history_pointer] = msgval;
            }
            history_pointer--;
            msg.value = history_list[history_pointer];
        }
        if ( isShift && e.keyCode == 40 && history_pointer < history_list.length ) { // shift + down arrow, history foreward
            var msg = document.getElementById('msg');
            var msgval = msg.value;
            if ( msgval.length > 0 && history_list[history_pointer] != msgval ) {
                history_list[history_pointer] = msgval;
            }
            history_pointer++;
            if ( history_pointer < history_list.length ) {
                msg.value = history_list[history_pointer];
            }
            else {
                msg.value = '';
            }
        }
    };

    /************************************************************************
     *** Fertisch                                                         ***
     ************************************************************************/
    t_start();
    receive();
    document.getElementById('msg').focus();
};

