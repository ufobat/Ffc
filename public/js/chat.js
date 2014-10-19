function set_title(newchatcount, newpostcount, newmsgscount) {
    var tp = ffcdata.title;
    var str = tp[0]+newchatcount+tp[1]+newpostcount+tp[2]+newmsgscount+tp[3];
    document.getElementsByTagName("title")[0].firstChild.data = str;
}
