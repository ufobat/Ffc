"use strict";
/************************************************************************
 * Start der Initialiserung von Features
 ************************************************************************/
ffcdata.features = {};
ffcdata.features.fileuploadchange = function(it){};
ffcdata.features.hidemessagebox   = function(it){};
ffcdata.features.init = function(){

    /************************************************************************
     * Webseitentitel anpassen
     ************************************************************************/
    var mytitle = document.getElementsByTagName("title")[0].firstChild.data;
    // Titel aktualisieren
    var set_title = function(cnt){
        mytitle = ffcdata.title[0] + cnt + ffcdata.title[1];
        ffcdata.lastcount = cnt;
        set_titletime();
    };
    // Aktualisierungszeitpunkt nach lokaler Uhrzeit in den Titel schreiben
    var set_titletime = function(){
        var mytime  = new Date();
        var myh = mytime.getHours(), mym = mytime.getMinutes();
        document.getElementsByTagName("title")[0].firstChild.data
            = mytitle + ', zuletzt aktualisiert '
                      + ( myh < 10 ? '0'+myh : myh )
                      + ':' + ( mym < 10 ? '0'+mym : mym );
    };

    /***********************************************************************
     * Desktopbenachrichtigungen bei neuen Nachrichten
     *************************************************************************/
    var notify_newmsgs = function(){
        if ( ffcdata.newmessagecount > 0 ) {
            ffcdata.utils.notify(
                'Es sind ' + ffcdata.newmessagecount + ' neue Beiträge vorhanden' );
        }
    };

    /************************************************************************
     * Chat-Button bei Bedarf aktivieren
     ************************************************************************/
    var activate_chatbutton = function(){
        if ( ffcdata.isinchat !== '' ) return;

        var chatb = document.getElementById('chatuserlist');
        if ( chatb )
            chatb.className = 'popuparrow forumoptionpopup menuentry';

        var chats = document.getElementById('menuchatseparator');
        if ( chats )
            chats.className = 'menubarseparator';

        var chats = document.getElementById('chatlink');
        if ( chats )
            chats.className = 'chatlink';
    };

    /************************************************************************
     * Auto-Refresh-Topicliste
     ************************************************************************/
    var auto_refresh_topiclist = function() {
        ffcdata.utils.request('GET', ffcdata.topiclisturl, null, function(res){
            var topiclist = document.getElementById('topiclist');
            if ( topiclist ) topiclist.outerHTML = res;
            var pages = document.getElementById('pages');
            if ( pages ) pages.outerHTML = '';
        }, true);
    };

    /************************************************************************
     * Auto-Refresh-Beitragsliste
     ************************************************************************/
    var auto_refresh_postlist = function() {
        var url = ffcdata.fetchnewurlunfocused;
        if ( document.hasFocus() )
            url = ffcdata.fetchnewurlfocused;

        ffcdata.utils.request('GET', url, 
            {
                pageurl:    ffcdata.pageurl, 
                queryurl:   ffcdata.queryurl, 
                controller: ffcdata.controller, 
                lastcount:  ffcdata.lastcount
            },
            function(res){
            if ( !res ) return;
            var boxes = document.getElementsByClassName('postbox');
            for ( var i = 2; i < boxes.length; i++ ) {
                if ( boxes[i] && res[i-2] ) boxes[i].outerHTML = res[i-2];
            }
            enable_highscore();
        }, false);
    };

    /************************************************************************
     * Auto-Refresh-Menu setzen
     ************************************************************************/
    var set_menu = function(res) {
        if ( !res ) return;
        var menu = document.getElementById('menu');
        if ( menu ) {
            menu.outerHTML = res;
            activate_chatbutton();
        }
    };

    /************************************************************************
     * Auto-Refresh-Chatbutton setzen
     ************************************************************************/
    var set_chatuserlist = function(users) {
        var chatbutton = document.getElementById('chatuserlist');
        if ( users && users.length > 0 ) {
            if ( chatbutton ) {
                var chatuserstr = '<p><a href="' + ffcdata.chaturl
                    + '" target="_blank">Chat</a>:</p>';
                for ( var i = 0; i < users.length; i++ ) {
                    chatuserstr = chatuserstr + '<p class="shiftin">';
                    if ( users[i][4] ) {
                        chatuserstr = chatuserstr 
                                    + '<a href="' + users[i][4] + '" target="_blank">'
                                    + users[i][0] + '</a>';
                    }
                    else {
                        chatuserstr = chatuserstr + users[i][0];
                    }
                    chatuserstr = chatuserstr + ' (' + users[i][1] + ')</p>';
                }
                chatbutton.innerHTML = chatuserstr;
                chatbutton.className = 'nodisplay popuparrow forumoptionpopup activedim menuentry';
            }
        }
        else {
            chatbutton.className = 'nodisplay';
        }
    };

    /************************************************************************
     * Auto-Refresh-Funktion
     ************************************************************************/
    var auto_refresh = function(){
        ffcdata.utils.request('POST', ffcdata.fetchurl, 
            {
                pageurl:    ffcdata.pageurl, 
                queryurl:   ffcdata.queryurl, 
                controller: ffcdata.controller, 
                lastcount:  ffcdata.lastcount
            }, 
            function(res){
                if ( ffcdata.istopiclist && res[0] > 0 && res[0] > ffcdata.lastcount) {
                    auto_refresh_topiclist();
                    ffcdata.newmessagecount = res[0];
                }
                if ( res[0] > 0 && res[0] > ffcdata.lastcount ) {
                    notify_newmsgs();
                }
                if ( res[0] > 0 && ffcdata.action === 'show' 
                    && ( ffcdata.controller === 'forum' || ffcdata.controller === 'pmsgs' ) )
                        auto_refresh_postlist();
                set_title(        res[0] );
                set_menu(         res[1] );
                set_chatuserlist( res[2] );
                return true;
            }
        );
    };

    /************************************************************************
     * Auto-Refresh nur für das Menü und den Titel bei Bedarf aktivieren
     ************************************************************************/
    var set_timerrefresh = function(){
        ffcdata.features.autorefresh_interval 
            = window.setInterval(auto_refresh, ffcdata.autorefresh * 1000 );
    };

    /************************************************************************
     * Auto-Refresh für das Menü, wenn das Themen-Fenster den Fokus erhält
     ************************************************************************/
    var set_focusrefresh = function(){
        window.onfocus = auto_refresh;
    };

    /************************************************************************
     * Dateihochladefelder ergänzen
     ************************************************************************/
    var set_upload_multi = function(){
        var uibox = document.getElementById('uploadinputsbox');
        if ( !uibox ) return;
        var uifield = document.getElementById('uploadinputfield');
        if ( !uifield ) return;
        var iter = 1;
        ffcdata.features.fileuploadchange = function(it){
            var val = it.value;
            if ( !val || val === '' || iter > 42 ) return;
            it.onchange = null;
            var uifieldnew = uifield.cloneNode(true);
            uifieldnew.firstChild.value = '';
            uibox.appendChild(uifieldnew);
            iter++;
        };
    };

    /************************************************************************
     * Benachrichtigungsfenster mittels Klick verschwinden lassen
     ************************************************************************/
    var enable_hidemessagebox = function(){
        ffcdata.features.hidemessagebox = function(it){
            if( !it ) return;
            it.style.display = 'none';
        };
    }

    /************************************************************************
     * Autorefresh-Option zuschalten
     ************************************************************************/
    var enable_autorefreshoption = function(){
        var optbox = document.getElementById('autorefreshoption');
        if ( optbox ) optbox.className = 'postbox options';
    };

    /************************************************************************
     * Highscore via Ajax setzen, falls möglich
     ************************************************************************/
    var set_ajax_highscorelink = function(link){
        var href = link.href + '/ajax';
        link.attributes.removeNamedItem('href');
        link.addEventListener("click", function(){
            link.onclick = undefined;
            link.className='hiddendisplay'
            link.removeEventListener('click', function(){ return 1 });
            ffcdata.utils.request('GET', href, null,
                function(res){
                    if ( !res ) return;
                    if ( ! (res === 'up' || res === 'down') ) return;
                    auto_refresh_postlist();
                },
                1 // data, nojason
            );
        });
    };
    var enable_highscore = function(){
        var scorelinks = document.getElementsByName('highscorelink'); 
        for ( var i = 0; i < scorelinks.length; i++ ) {
            set_ajax_highscorelink(scorelinks[i]);
        }
    };

    /************************************************************************
     * Features initial aktiveren
     ************************************************************************/
    var enable_strg_s = function() {
        var tif = document.getElementById('textinputform'); 
        if ( tif ) {
            // console.log(tif);
            tif.onkeydown = function(ev) {
                // console.log(ev.keyCode + '-' + ev.ctrlKey);
                if (ev.keyCode == 83 && ev.ctrlKey) {
                    tif.submit();
                    ev.preventDefault();
                }
            };
        }
    };

    /************************************************************************
     * Features initial aktiveren
     ************************************************************************/
    if ( !ffcdata.singleuser )
        set_titletime();
    activate_chatbutton();
    if ( ffcdata.autorefresh > 0 && !ffcdata.utils.is_disabled() && !ffcdata.singleuser ) {
        set_timerrefresh();
        set_focusrefresh();
        auto_refresh();
    }
    set_upload_multi();
    enable_hidemessagebox();
    enable_strg_s();
    enable_autorefreshoption();
    enable_highscore();
    notify_newmsgs();
    ffcdata.features.set_menu = set_menu;
};

