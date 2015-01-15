ffcdata.features = {};

ffcdata.features.init = function(){
    var menu = document.getElementById('menu');
    var menutop = menu.offsetTop;
    var headbox = document.getElementById('headbox');
    if ( headbox ) {
        var headboxtop = headbox.offsetTop;
        var headboxmargintop = headbox.style["margin-top"];
    }
    var menumargintop = menu.style["margin-top"];
    var menuheight = menu.clientHeight;
    var menuclass = menu.className;
    var menubordertopwidth = menu.style["border-top-width"];
    menu.style.width = menu.clientWidth + 'px';

    // Auto-Refresh einsetzen
    var set_autorefresh = function(){
        if ( ffcdata.utils.is_disabled() ) return;
        ffcdata.features.autorefresh_interval = window.setInterval(function(){
            if ( !document.hasFocus() 
              && (!document.getElementById('textinput') 
                || document.getElementById('textinput').value === '') ) {
                location.reload();
            }
        }, ffcdata.autorefresh * 60000 );
    };
    
    // Aktualisierungszeitpunkt nach lokaler Uhrzeit in den Titel schreiben
    var set_titletime = function(){
        var mytitle = document.getElementsByTagName("title")[0].firstChild.data;
        var mytime  = new Date();
        var myh = mytime.getHours(), mym = mytime.getMinutes();
        document.getElementsByTagName("title")[0].firstChild.data
            = mytitle + ', zuletzt aktualisiert ' 
                      + ( myh < 10 ? '0'+myh : myh ) 
                      + ':' + ( mym < 10 ? '0'+mym : mym );
    };

    // Menuscrolling
    var menuscroll_init = function(){
        var inscroll = false;
        window.onscroll = function(){
            // console.log('scroll');
            if ( inscroll && window.scrollY <= menutop ) {
                // console.log('scrolled back to top');
                inscroll = false;
                menu.style.top = 'inherit';
                menu.style.position = 'inherit';
                menu.style["border-top-width"] = menubordertopwidth;
                menu.style["margin-top"] = menumargintop;
                headbox.style["margin-top"] = headboxmargintop;
                menu.className = menuclass;
                return;
            }
            if ( !inscroll && window.scrollY > menutop + 1 ) {
                // console.log('scrolled over menu');
                inscroll = true;
                menu.style.position = 'fixed';
                menu.style["border-top-width"] = 0;
                menu.style.top = 0;
                menu.style["margin-top"] = 0;
                menu.className = menuclass + (menuclass ? ' ' : '') + 'shadowed';
                headbox.style["margin-top"] = '' + headboxmargintop + menumargintop + menuheight + 'px';
            }
        };
    };

    // Weitere Feature-Operationen starten
    set_titletime();
    if ( !ffcdata.utils.is_disabled() ) 
        menuscroll_init();
    if ( ffcdata.autorefresh > 0 ) 
        set_autorefresh();
};

