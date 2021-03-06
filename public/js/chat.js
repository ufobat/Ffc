"use strict";
/************************************************************************
 *** Initialisierung mit allen notwendigen Funktionen                 ***
 ************************************************************************/

ffcdata.chat.init = function() {
    var msgfield                   = document.getElementById('textinput');
    var titlenode                  = document.getElementsByTagName("title")[0].firstChild
    var refreshtimefield           = document.getElementById('refreshtime');
    var msglog                     = document.getElementById('msglog');
    var userlist                   = document.getElementById('userlist');
    var notifyswitch               = document.getElementById('notifyswitch');
    var attachement                = document.getElementById('attachement');
    var sendonentercheck           = document.getElementById('sendonentercheck');
    var chatuploadform             = document.getElementById('chatuploadform');
    var chatuploadpopupfield       = document.getElementById('chatuploadpopup');
    var chatuploadpopup            = document.getElementById('chatuploadpopup');
    var chatuploadpopupswitch      = document.getElementById('chatuploadpopupswitch');
    var chatuploadpopupswitchclass = chatuploadpopupswitch.className.toString();
    var chatuploadpopupfieldclass  = chatuploadpopupfield.className.toString();
    var chatuploadpopupclass       = chatuploadpopup.className.toString();

    /************************************************************************
     *** Chat-Text formatieren                                            ***
     ************************************************************************/
    var usernamefilter = function(txt) {
        txt = txt.replace(ffcdata.chat.userre, '$1<span class="myself">$2</span>$3');
        return(txt);
    };

    /************************************************************************
     *** Titelstring der Webseite aendern                                 ***
     ************************************************************************/
    var set_title = function(newchatcount, newpostcount, newmsgscount, startet) {
        var tp = ffcdata.chat.title;
        if ( document.hasFocus() || startet )
            ffcdata.chat.newchatcountsum = 0;
        else 
            ffcdata.chat.newchatcountsum = ffcdata.chat.newchatcountsum + newchatcount;

        var str = ffcdata.chat.newchatcountsum + tp[0]
                + newpostcount + tp[1] + newmsgscount + tp[2] + tp[3];

        titlenode.data = str;
        // console.log('title updated');
    };

    /************************************************************************
     *** Refresh-Auswahl aktualisieren                                    ***
     ************************************************************************/
    var update_refreshtime = function(ref) {
        refreshtimefield.value = ref;
        ffcdata.chat.refresh = ref;
        // console.log('refresh time view updated: '+ref);
    };

    /************************************************************************
     *** Benutzerliste befuellen                                          ***
     ************************************************************************/
    var update_userlist = function(users) {
        var ul = '';
        for ( var i = 0; i < users.length; i++ ) {
            var uh = '';
            if ( users[i][4] !== '' ) {
                uh = '<a href="' + users[i][4] + '" target="_blank">' + users[i][0] + '</a>';
                if ( users[i][5] )
                    uh = uh + ' (' + users[i][5] + ')';
            }
            else {
                uh = users[i][0];
            }
            uh = '<img class="avatar" src="' + users[i][6] + '" /><span class="username">' + uh + '</span>';
            ul = ul +'<p>' + uh + '<br /><span class="timestamp">(';
            if ( users[i][2] >= 60 )
                ul = ul + ( users[i][2] / 60 ) + 'min';
            else
                ul = ul + users[i][2] + 'sec';
            ul = ul + ', ' + users[i][1] + ')</span></p>';
            if ( users[i][0] === ffcdata.user )
                update_refreshtime(users[i][2]);
        }
        userlist.innerHTML = ul;
        // console.log('userlist updated');
    };

    /************************************************************************
     *** Neue Chatnachrichten zusammenbauen                               ***
     ************************************************************************/
    var compose_msg = function(msgs, i, started){
        var msg            = msgs[i];
        var newdaymsg      = false;
        var userstrthing   = '';
        var userstr        = '';
        var msgstr         = msg[2];
        var classstr       = [];
        var userstrthing   = '';
        var userstr        = msg[1];
        var classstr       = [];
        var newdate        = '';
        var usernameprefix = '';

        var match_o = ffcdata.chat.lastmsgtime.match(/\d\d\d\d-\d\d-\d\d/);
        var match_n = msg[3].match(/\d\d\d\d-\d\d-\d\d/);
        //console.log(match_o + ' → ' + match_n);
        if ( match_n && ( !match_o || ( match_o[0] != match_n[0] ) ) ) {
            var ndm = match_n[0].match(/(\d\d\d\d)-(\d\d)-(\d\d)/);
            newdate = '<div class="chatmsgbox newdaymsg">' + ndm[3] + '.' + ndm[2] + '.' + ndm[1] + '</div>';
        }
        ffcdata.chat.lastmsgtime = msg[3];

        if ( started ) classstr.push('startmsg');
        var sameuser = ffcdata.chat.lastmsguser === msg[1];

        var timepart = msg[3].match(/\d\d:\d\d/);
        var mecmd = false;
        if ( msg[2].match(/^\/me\s+/ ) ) {
            msg[2] = msg[2].replace(/^\/me\s+/, '');
            userstr = msg[1] + ' ';
            mecmd = true;
        }
        if ( ffcdata.user === msg[1] ) classstr.push('ownmsg');
        userstrthing = ( !sameuser || mecmd || newdaymsg ? userstr : '' );
        if ( msg[4] === 0 ) {
            msgstr = usernamefilter(msg[2]);
        }

        classstr.push('sameuser');
        ffcdata.chat.lastmsguser = msg[1];
        if ( msg[4] !== 0  && !sameuser ) {
            sameuser = '';
        }
        if ( msg[5] != ffcdata.userid ) {
            userstr = '<a href="' + msg[6] + '" target="_blank" title="Private Nachricht senden" class="chatusernamelink">' + userstr + '</a>';
        }
        userstr = '<img src="' + msg[8] + '" class="avatar" /><span class="username">' + userstr + '</span>';

        if ( !sameuser ) {
           usernameprefix = '<div class="chatmsgbox usernameline">' + userstr + '</div>\n';
        }

        return newdate
           + usernameprefix
           + '<div class="chatmsgbox' 
           + ( ( classstr.length > 0 ? ' ' : '' ) + classstr.join(' ') ) 
           + '">'
           + '<div class="chatmsgprefix"><div class="chatmsgprefixinner"><span class="timestamp">(' + timepart + ')</span> '
           + '</div></div><div class="chatmsgcontent">' + msgstr
           + '</div></div>\n';
    }

    /************************************************************************
     *** Neue Chatnachrichten anzeigen                                    ***
     ************************************************************************/
    var add_msgs = function(msgs, started) {
        if ( msgs.length > 0 ) {
            var ml = msglog.innerHTML;
            var relevantcnt = 0;
            for ( var i = msgs.length - 1; i >= 0; i-- ) {
                ml = ml + compose_msg(msgs, i, started);
                if ( msgs[i][5] != ffcdata.userid ) relevantcnt++;
            }
            if ( !document.hasFocus() && !started && relevantcnt > 0 ) {
                if ( msgs.length === 1 ) { ffcdata.utils.notify('Es ist eine neue Nachricht im Chat'); }
                else { ffcdata.utils.notify('Es sind ' + msgs.length + ' neue Nachrichten im Chat'); }
            }

            msglog.innerHTML = ml;

            var scrollHeight = Math.max(msglog.scrollHeight, msglog.clientHeight);
            msglog.scrollTop = scrollHeight - msglog.clientHeight;

            // console.log('new messages added');
        }
    };

    /************************************************************************
     *** Anzahl neuer nicht eigener Chat-Nachrichten                      ***
     ************************************************************************/
    var get_newmsg_count = function(msgs){
        var cnt = 0;
        for( var i=0; i < msgs.length; i++ ) {
            if ( ffcdata.user !== msgs[i][1] )
                cnt++;
        }
        return cnt;
    };

    /************************************************************************
     *** Empfangene Daten verwerten                                       ***
     ************************************************************************/
    var resolve = function(data, started) {
        // console.log('resolving fetched data');
        // Titel aktualisieren - aber nicht beim Beginn des Chats
        set_title(get_newmsg_count(data[0]), data[2], data[3], started);

        // Benutzerliste aktualisieren
        update_userlist(data[1]);

        // Menü aktualisieren
        ffcdata.features.set_menu( data[4] );

        // Neue Nachrichten ins Log schreiben
        add_msgs(data[0], started);

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
        if ( !t_stop() && !started ) {
            // console.log('timeout allready stopped, receive might be in progress');
            return;
        }
        // console.log('fetching data');
        var revfun = function(data){resolve(data,started)};

        var url    = ffcdata.chat.unfocusedurl;
        if ( document.hasFocus() ) url = ffcdata.chat.focusedurl;
        if ( started             ) url = ffcdata.chat.startedurl;
        
        ffcdata.utils.request(( msg ? 'POST' : 'GET' ), url, msg,  revfun);
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
        }, true);
    };

    /************************************************************************
     *** Den Chat verlassen                                               ***
     ************************************************************************/
    window.addEventListener('beforeunload', function(e) {
        ffcdata.utils.request('GET', ffcdata.chat.leaveurl, null, function(ret) { 
            console.log(ret);
        }, true, true, true);
        return true;
    });

    /************************************************************************
     *** Chatfenster anwaehlen                                            ***
     ************************************************************************/
    var onfocus_fun = function() {
        // console.log('got focused');
        msgfield.focus();
        receive();
    };

    /************************************************************************
     *** Refresh-Einstellung wechseln                                     ***
     ************************************************************************/
    refreshtimefield.addEventListener('change', function() {
        // console.log('refresh time changed');
        set_refresh(this.value);
    });

    /************************************************************************
     *** Manuelles Neuladen                                               ***
     ************************************************************************/
    document.getElementById('reload').addEventListener('click', function() {
        // console.log('manual reload triggered');
        receive();
    });

    /************************************************************************
     *** Message-Log leeren                                               ***
     ************************************************************************/
    var clrscr = function() {
        msglog.innerHTML = '';
        ffcdata.chat.lastmsguser = '';
    };
    document.getElementById('clrscr').addEventListener('click', function(e) {
        // console.log('clear message log');
        clrscr();
    });

    /************************************************************************
     *** Desktopbenachrichtigungserlaubenseinstellung                     ***
     ************************************************************************/
    notifyswitch.addEventListener('change', function(){
        if ( notifyswitch.checked ) {
            ffcdata.notifications = true;
        }
        else {
            ffcdata.notifications = false;
        }
    });

    /************************************************************************
     *** Absenden                                                         ***
     ************************************************************************/
    var sendit = function() {
        var msgval = msgfield.value;
        if ( msgval ) {
            ffcdata.chat.history_list.push(msgval);
            ffcdata.chat.history_pointer = ffcdata.chat.history_list.length;
        }
        receive(msgfield.value);
        msgfield.focus();
    };
    var cleanmsg = function() {
        msgfield.value = '';
    }

    /************************************************************************
     *** Manuelles Absenden                                               ***
     ************************************************************************/
    document.getElementById('send').addEventListener('click', function() {
        // console.log('manual send triggered');
        sendit();
        cleanmsg();
    });

    /************************************************************************
     *** Enter-Absenden                                                   ***
     ************************************************************************/
    msgfield.addEventListener('keydown', function(e) {
        // console.log(e.keyCode);
        if ( e.keyCode == 13 && !( e.shiftKey || !sendonentercheck.checked ) ) {
            // console.log('enter-key send triggered');
            sendit();
            cleanmsg();
        }
    });
    msgfield.addEventListener('keyup', function(e) {
        // console.log(e.keyCode);
        if ( e.keyCode == 13 && !( e.shiftKey || !sendonentercheck.checked ) ) {
            //console.log('enter-key send done');
            if ( msgfield.value.match(/^[\s\r\n]+$/) ) cleanmsg();
        }
        
        // shift + up arrow, history back
        if ( e.shiftKey && e.keyCode == 38 && ffcdata.chat.history_pointer > 0 ) {
            var msgval = msgfield.value;
            if ( msgval.length > 0 && ffcdata.chat.history_list[ffcdata.chat.history_pointer] != msgval ) {
                ffcdata.chat.history_list[ffcdata.chat.history_pointer] = msgval;
            }
            ffcdata.chat.history_pointer--;
            msgfield.value = ffcdata.chat.history_list[ffcdata.chat.history_pointer];
        }

        // shift + down arrow, history foreward
        if ( e.shiftKey && e.keyCode == 40 && ffcdata.chat.history_pointer < ffcdata.chat.history_list.length ) {
            var msgval = msgfield.value;
            if ( msgval.length > 0 && ffcdata.chat.history_list[ffcdata.chat.history_pointer] != msgval ) {
                ffcdata.chat.history_list[ffcdata.chat.history_pointer] = msgval;
            }
            ffcdata.chat.history_pointer++;
            if ( ffcdata.chat.history_pointer < ffcdata.chat.history_list.length ) {
                msgfield.value = ffcdata.chat.history_list[ffcdata.chat.history_pointer];
            }
            else {
                msgfield.value = '';
            }
        }
    });

    /************************************************************************
     *** Uploads im Chatfenster                                           ***
     ************************************************************************/
    var attach_fun = function(ev){
        ev.preventDefault();
        chatuploadpopup.className       = 'nodisplay';
        chatuploadpopupfield.className  = chatuploadpopupfieldclass;
        chatuploadpopupswitch.className = chatuploadpopupswitchclass + ' dimmer';

        var fData = new FormData(chatuploadform);
        var req = new XMLHttpRequest();
        req.open("POST", ffcdata.chat.uploadurl);
        req.addEventListener("load", function() {
            if (req.status === 200 && req.responseText === 'ok' ) {
                chatuploadpopupswitch.className = chatuploadpopupswitchclass;
                msgfield.focus();
            } else {
                alert('Dateiuploads funktionieren hier nicht');
            }
        });
        req.send(fData);
        attachement.value = '';
    };

    /************************************************************************
     *** Fertisch                                                         ***
     ************************************************************************/
    receive_start();
    msgfield.focus();
    
    attachement.addEventListener('change', attach_fun);
    window.addEventListener('focus', onfocus_fun);
};

