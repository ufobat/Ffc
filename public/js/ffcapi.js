"use strict";
// JavaShit
ffcapi = {};
(function(){



/******************************************************************************
 ******************************************************************************
 ***   Helper                                                               ***
 ******************************************************************************
 ******************************************************************************/
var acall = function(method, url, data = null) {
    try {
        // console.log('starting request');
        var req = new XMLHttpRequest();
        req.open(method, url, true);
        req.addEventListener("load", function() {
                if (req.status < 400)
                    return(JSON.parse(req.responseText))
                else
                    new Error("Request failed: " + req.statusText);
            }
        );
        req.addEventListener("error", function() {
            new Error("Network error");
        }); 

        if ( methd === 'POST' ) { 
            req.setRequestHeader("Content-type", "multipart/formdata");
            req.setRequestHeader("Connection", "close");
            req.send(JSON.stringify(data));
        }   
        else {
            req.send();
        }   
    }   
    catch (e) {
        console.log('Error on request: ' + e); 
    }
};
var aget    = function(url)       { acall('GET',    url       ) };
var apost   = function(url, data) { acall('POST',   url, data ) };
var adelete = function(url)       { acall('DELETE', url       ) };



/******************************************************************************
 ******************************************************************************
 ***   Handler                                                              ***
 ******************************************************************************
 ******************************************************************************/



/******************************************************************************
 * Topics                                                                     *
 ******************************************************************************/
ffcapi.topics_get = function(limit = 10, offset = 0) {
    return aget( '/topics/get/limit/' + limit + '/offset/' + offset) };
ffcapi.topics_add = function(titlestr) {
    return apost('/topics/add', {title => titlestr}) };
ffcapi.topics_edit = function(topicid,titlestr) {
    return apost('/topics/' + topicid + '/edit', {title => $titlestr}) };
ffcapi.topics_pin = function(topicid) {
    return aget( '/topics/' + topicid + '/pin') };
ffcapi.topics_unpin = function(topicid) {
    return aget( '/topics/' + topicid + '/unpin') };
ffcapi.topics_ignore = function(topicid) {
    return aget( '/topics/' + topicid + '/ignore') };
ffcapi.topics_unignore = function(topicid) {
    return aget( '/topics/' + topicid + '/unignore') };

/******************************************************************************
 * Posts                                                                      *
 ******************************************************************************/
//~ GET    /topics/#/posts/get/limit/#/offset/#
//~ POST   /topics/#/posts/add
//~ POST   /topics/#/posts/#/edit
//~ DELETE /topics/#/posts/#/delete

/******************************************************************************
 * Attachements                                                               *
 ******************************************************************************/
//~ GET    /topics/#/posts/#/attachements/get
//~ POST   /topics/#/posts/#/attachements/add
//~ GET    /topics/#/posts/#/attachements/#/get
//~ DELETE /topics/#/posts/#/attachements/#/delete

/******************************************************************************
 * Comments                                                                   *
 ******************************************************************************/
//~ GET    /topics/#/posts/#/comments/get/limit/#/offset/#
//~ POST   /topics/#/posts/#/comments/add
//~ POST   /topics/#/posts/#/comments/#/edit
//~ DELETE /topics/#/posts/#/comments/#/delete

/******************************************************************************
 * Usermessage                                                                *
 ******************************************************************************/
//~ GET    /users/get
//~ GET    /users/#/messages/get/limit/#/offset/#
//~ POST   /users/#/messages/add

/******************************************************************************
 * Chat                                                                       *
 ******************************************************************************/
//~ GET    /chat/join
//~ GET    /chat/leave
//~ GET    /chat/messages/get
//~ POST   /chat/messages/add

/******************************************************************************
 * User-Configuration                                                         *
 ******************************************************************************/
//~ POST   /config/password/edit
//~ GET    /config/usercolor/set/#
//~ GET    /config/bgcolor/set/#

/******************************************************************************
 * Board-Administration                                                        *
 ******************************************************************************/
//~ POST   /admin/title/set
//~ GET    /admin/language/set/#

/******************************************************************************
 * User-Administration                                                        *
 ******************************************************************************/
//~ GET    /admin/users/show
//~ POST   /admin/users/#/name/edit
//~ GET    /admin/users/#/isadmin
//~ GET    /admin/users/#/notadmin
//~ GET    /admin/users/#/active
//~ GET    /admin/users/#/inactive

})();
