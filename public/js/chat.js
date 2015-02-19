"use strict";
/************************************************************************
 *** Initialisierung mit allen notwendigen Funktionen                 ***
 ************************************************************************/

ffcdata.chat.init = function() {
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
            txt = txt.replace(ffcdata.chat.userre, '<span class="myself">$1</span>');
        }
        return(txt);
    }

    /************************************************************************
     *** Titelstring der Webseite aendern                                 ***
     ************************************************************************/
    var set_title = function(newchatcount, newpostcount, newmsgscount) {
        var tp = ffcdata.chat.title;
        if ( document.hasFocus() )
            ffcdata.chat.newchatcountsum = 0;
        else 
            ffcdata.chat.newchatcountsum = ffcdata.chat.newchatcountsum + newchatcount;
        var str = tp[0]+ffcdata.chat.newchatcountsum+tp[1]+(newpostcount+newmsgscount)+tp[2];
        document.getElementsByTagName("title")[0].firstChild.data = str;
        // console.log('title updated');
    };

    /************************************************************************
     *** Refresh-Auswahl aktualisieren                                    ***
     ************************************************************************/
    var update_refreshtime = function(ref) {
        document.getElementById('refreshtime').value = ref;
        ffcdata.chat.refresh = ref;
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
            var newdaymsg = false;
            for ( var i = msgs.length - 1; i >= 0; i-- ) {
                newdaymsg = false;
                var match_n = msgs[i][3].match(/\d\d\.\d\d\.\d\d\d\d/);
                if ( i < msgs.length - 1 ) {
                    var match_a = msgs[i + 1][3].match(/\d\d\.\d\d\.\d\d\d\d/);
                    if ( match_a && ( !match_n || match_n[0] !== match_a[0] ) ) {
                        newdaymsg = true;
                    }
                }
                else {
                    var match_l = ffcdata.chat.lastmsgtime.match(/\d\d\.\d\d\.\d\d\d\d/);
                    if ( match_l && ( !match_n || match_n[0] !== match_l[0] ) ) {
                        newdaymsg = true;
                    }
                }
                if ( msgs[i][2].match(/^\/me\s+/ ) ) {
                    msgs[i][2] = msgs[i][2].replace(/^\/me\s+/, '');
                    userstr = msgs[i][1] + ' ';
                }
                else {
                    userstr = '<span class="username">' + msgs[i][1] + '</span>: ';
                }
                ml = ml
                   + ( newdaymsg 
                        ? '<p class="newdaymsg' + (ffcdata.user === msgs[i][1] ? ' ownmsg' : '') + '">'
                        : '<p' + (ffcdata.user === msgs[i][1] ? ' class="ownmsg"' : '') + '>' )
                   + '<span class="timestamp">(' + msgs[i][3] + ')</span> '
                   + userstr + textfilter(msgs[i][2]) + '</p>\n';
            }
            msglog.innerHTML = ml;
            ffcdata.chat.lastmsgtime = msgs[0][3];

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
        if ( ffcdata.chat.to ) {
            window.clearTimeout(ffcdata.chat.to);
            // console.log('timeout stopped');
            return true;
        }
        else {
            // console.log('no timeout set yet');
            return false;
        }
    };
    var t_start = function() {
        ffcdata.chat.to = window.setTimeout(receive, ffcdata.chat.refresh * 1000);
        // console.log('timeout startet: '+refresh);
    };

    /************************************************************************
     *** Daten abholen                                                    ***
     ************************************************************************/
    var receive_do = function(msg, started) {
        // console.log('receiving');
        if ( !t_stop() ) {
            // console.log('timeout allready stopped, receive might be in progress');
            return;
        }
        // console.log('fetching data');
        var url = ffcdata.chat.unfocusedurl;
        if ( document.hasFocus() )
            url = ffcdata.chat.focusedurl;
        if ( started )
            url = ffcdata.chat.startedurl;
        if ( msg )
            ffcdata.utils.request('POST', url, msg, resolve);
        else
            ffcdata.utils.request('GET', url, null, resolve);
    };
    var receive = function(msg) { receive_do(msg, false) };
    var receive_start = function() { receive_do(false, true); };

    /************************************************************************
     *** Refresh-Zeit aendern                                             ***
     ************************************************************************/
    var set_refresh = function(value) {
        var url = ffcdata.chat.refreshseturl.substring(0, ffcdata.chat.refreshseturl.length - 2);
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
        ffcdata.utils.request('GET', ffcdata.chat.leaveurl, null, function(ret) { console.log(ret); });
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
                ffcdata.chat.history_list.push(msgval);
                ffcdata.chat.history_pointer = ffcdata.chat.history_list.length;
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

        if ( isShift && e.keyCode == 38 && ffcdata.chat.history_pointer > 0 ) { // shift + up arrow, history back
            var msg = document.getElementById('msg');
            var msgval = msg.value;
            if ( msgval.length > 0 && ffcdata.chat.history_list[ffcdata.chat.history_pointer] != msgval ) {
                ffcdata.chat.history_list[ffcdata.chat.history_pointer] = msgval;
            }
            ffcdata.chat.history_pointer--;
            msg.value = ffcdata.chat.history_list[ffcdata.chat.history_pointer];
        }
        if ( isShift && e.keyCode == 40 && ffcdata.chat.history_pointer < ffcdata.chat.history_list.length ) { // shift + down arrow, history foreward
            var msg = document.getElementById('msg');
            var msgval = msg.value;
            if ( msgval.length > 0 && ffcdata.chat.history_list[ffcdata.chat.history_pointer] != msgval ) {
                ffcdata.chat.history_list[ffcdata.chat.history_pointer] = msgval;
            }
            ffcdata.chat.history_pointer++;
            if ( ffcdata.chat.history_pointer < ffcdata.chat.history_list.length ) {
                msg.value = ffcdata.chat.history_list[ffcdata.chat.history_pointer];
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
    receive_start();
    document.getElementById('msg').focus();
};

