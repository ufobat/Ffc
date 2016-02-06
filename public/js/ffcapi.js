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
        req.open(method, ffcdata.baseurl + url, true);
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
var aupload = function(){alert('not impplemented yet')}
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
    return aget( 'topics/get/limit/' + limit + '/offset/' + offset) };
ffcapi.topics_add = function(titlestr) {
    return apost('topics/add', {title: titlestr}) };
ffcapi.topics_edit = function(topicid,titlestr) {
    return apost('topics/' + topicid + '/edit', {title: titlestr}) };

/******************************************************************************
 * Topic-Markers                                                              *
 ******************************************************************************/
ffcapi.topics_pin = function(topicid) {
    return aget( 'topics/' + topicid + '/pin') };
ffcapi.topics_unpin = function(topicid) {
    return aget( 'topics/' + topicid + '/unpin') };
ffcapi.topics_ignore = function(topicid) {
    return aget( 'topics/' + topicid + '/ignore') };
ffcapi.topics_unignore = function(topicid) {
    return aget( 'topics/' + topicid + '/unignore') };

/******************************************************************************
 * Topics: Posts-get and Posts-add                                            *
 ******************************************************************************/
ffcapi.topics_posts_get = function(topicsid, limit = 10, offset = 0) {
    return aget(   'topics/' + topicsid + '/posts/get/limit/' + limit + '/offset/' + offset) };
ffcapi.topics_posts_add = function(topicsid, text) {
    return apost(  'topics/' + topicsid + '/add', {textdata: text}) };

/******************************************************************************
 * Users                                                                      *
 ******************************************************************************/
ffcapi.users_get = function() {
    return aget( 'users/get') };

/******************************************************************************
 * Users: Posts-get and Posts-add                                             *
 ******************************************************************************/
ffcapi.messages_posts_get = function(messagesid, limit = 10, offset = 0) {
    return aget(   'messages/' + messagesid + '/posts/get/limit/' + limit + '/offset/' + offset) };
ffcapi.messages_posts_add = function(messagesid, text) {
    return apost(  'messages/' + messagesid + '/add', {textdata: text}) };

/******************************************************************************
 * Posts altering                                                             *
 ******************************************************************************/
ffcapi.posts_edit = function(postsid,text) {
    return apost(  'posts/' + postsid + '/edit', {textdata: text}) };
ffcapi.posts_delete = function(postid) {
    return adelete('posts/' + postsid + '/delete') };

/******************************************************************************
 * Attachements                                                               *
 ******************************************************************************/
ffcapi.attachements = function(postsid) {
    return aget(   'posts/' + postsid + '/attachements/get') };
ffcapi.attachements_posts_add = function(postsid) {
    return aupload('posts/' + postsid + '/attachements/add') };
ffcapi.attachements_get = function(attachmentsid) {
    return aget(   'attachements/' + attachmentsid + '/get') };
ffcapi.attachements_delete = function(attachementsid) {
    return adelete('attachements/' + attachementsid + '/delete') };

/******************************************************************************
 * Comments                                                                   *
 ******************************************************************************/
ffcapi.comments = function(postsid, limit = 10, offset = 0) {
    return aget(   'comments/' + postsid + '/get/limit/' + limit + '/offset/' + offset') };
ffcapi.comments_add  = function(commentsid) {
    return apost(  'comments/' + postsid + '/add') };
ffcapi.comments_edit = function(commentssid) {
    return aget(   'comments/' + commentsid + '/get') };
ffcapi.comments_delete = function(commentsid) {
    return adelete('comments/' + commentsid + '/delete') };

/******************************************************************************
 * Searches                                                                   *
 ******************************************************************************/
//~ POST   /topics/search
//~ POST   /topics/#/posts/search
//~ POST   /users/#/messages/search

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
