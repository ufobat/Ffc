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
        var chatb = document.getElementById('chatbutton');
        var chats = document.getElementById('menuchatseparator');
        if ( chatb )
            chatb.className = 'menuentry chatlink';
        if ( chats )
            chats.className = 'menubarseparator';
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
     * Auto-Refresh-Menu setzen
     ************************************************************************/
    var set_menu = function(res) {
        if ( !res ) return;
        var menu = document.getElementById('menu');
        if ( menu ) menu.outerHTML = res;
    };

    /************************************************************************
     * Auto-Refresh-Chatbutton setzen
     ************************************************************************/
    var set_chatbutton = function(res) {
        if ( !res ) return;
        var chatbutton = document.getElementById('chatbutton');
        if ( chatbutton ) {
            chatbutton.outerHTML = res;
            activate_chatbutton();
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
                if ( res[0] > 0 && res[0] > ffcdata.lastcount) {
                    notify_newmsgs();
                set_title(      res[0] );
                set_menu(       res[1] );
                set_chatbutton( res[2] );
                return true;
            }
        );
    };

    /************************************************************************
     * Auto-Refresh nur für das Menü und den Titel bei Bedarf aktivieren
     ************************************************************************/
    var set_menurefresh = function(){
        ffcdata.features.autorefresh_interval 
            = window.setInterval(auto_refresh, ffcdata.autorefresh * 60000 );
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
        set_menurefresh();
        set_focusrefresh();
    }
    set_upload_multi();
    enable_hidemessagebox();
    enable_strg_s();
    notify_newmsgs();
};

