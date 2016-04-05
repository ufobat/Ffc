"use strict";
// JavaShit
ffcapi = {};
(function(){



/******************************************************************************
 ******************************************************************************
 ***   Internal Helpers                                                     ***
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
 * General                                                                    *
 ******************************************************************************/
ffcapi.countings = function() {
    return aget('countings') };

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
ffcapi.topics_posts_get_new = function() {
    return aget(   'topics/posts/get/new') };
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
ffcapi.users_posts_get_new = function() {
    return aget(   'users/posts/get/new') };
ffcapi.users_posts_get = function(usersid, limit = 10, offset = 0) {
    return aget(   'users/' + usersid + '/posts/get/limit/' + limit + '/offset/' + offset) };
ffcapi.users_posts_add = function(messagesid, text) {
    return apost(  'users/' + usersid + '/add', {textdata: text}) };

/******************************************************************************
 * Posts altering                                                             *
 ******************************************************************************/
ffcapi.posts_edit = function(postsid,text) {
    return apost(  'posts/' + postsid + '/edit', {textdata: text}) };
ffcapi.posts_delete = function(postid) {
    return adelete('posts/' + postsid + '/delete') };

/******************************************************************************
 * Comments                                                                   *
 ******************************************************************************/
ffcapi.comments = function(postsid, limit = 10, offset = 0) {
    return aget(   'posts/' + postsid + '/comments/get/limit/' + limit + '/offset/' + offset) };
ffcapi.comments_add  = function(commentsid) {
    return apost(  'posts/' + postsid + '/comments/add') };

/******************************************************************************
 * Attachements                                                               *
 ******************************************************************************/
ffcapi.attachements = function(postsid) {
    return aget(   'posts/' + postsid + '/attachements/get') };
ffcapi.attachements_add = function(postsid) {
    return aupload('posts/' + postsid + '/attachements/add') };
ffcapi.attachements_get = function(attachmentsid) {
    return aget(   'attachements/' + attachmentsid + '/get') };
ffcapi.attachements_delete = function(attachementsid) {
    return adelete('attachements/' + attachementsid + '/delete') };

/******************************************************************************
 * Searches                                                                   *
 ******************************************************************************/
ffcapi.topics_search = function(searchstr) {
    return apost( '/topics/search', { search: searchstr } ) };
ffcapi.topics_posts_search = function(topicsid, searchstr) {
    return apost( '/topics/' + topicsid + '/posts/search', { search: searchstr } ) };
ffcapi.topics_posts_search = function(userssid, searchstr) {
    return apost( '/users/' + usersid + '/posts/search', { search: searchstr } ) };

/******************************************************************************
 * User-Configuration                                                         *
 ******************************************************************************/
ffcapi.config_password_edit = function(npassword1) {
    return apost( '/config/password/set', { npassword: npassword1 } ) };
ffcapi.config_usercolor = function(colorhex) {
    return aget( '/config/usercolor/set/' + colorhex ) };
ffcapi.config_bgcolor = function(colorhex) {
    return aget( '/config/bgcolor/set/' + colorhex ) };

/******************************************************************************
 * Board-Administration                                                       *
 ******************************************************************************/
ffcapi.admin_config_get = function() {
    return aget('/admin/config/get') };
ffcapi.admin_forumtitle = function(titlestr) {
    return apost( '/admin/title/set', { title: titlestr } ) };
ffcapi.admin_forumlanguage = function(languagestr) {
    return aget( '/admin/language/set/' + languagestr ) };

/******************************************************************************
 * User-Administration                                                        *
 ******************************************************************************/
ffcapi.admin_users_get = function() {
    return aget( '/admin/users/get' ) };
ffcapi.admin_users_add = function(nname) {
    return apost( '/admin/users/add', { name: namestr } ) };
ffcapi.admin_users_name_edit = function(usersid, nname) {
    return apost( '/admin/users/' + usersid + '/name/edit', { name: namestr } ) };
ffcapi.admin_users_isadmin = function(usersid) {
    return apost( '/admin/users/' + usersid + '/set/isadmin' ) };
ffcapi.admin_users_notadmin = function(usersid) {
    return apost( '/admin/users/' + usersid + '/set/notadmin' ) };
ffcapi.admin_users_active = function(usersid) {
    return apost( '/admin/users/' + usersid + '/set/active' ) };
ffcapi.admin_users_inactive = function(usersid) {
    return apost( '/admin/users/' + usersid + '/set/inactive' ) };



/******************************************************************************
 ******************************************************************************
 ***   API is there                                                         ***
 ******************************************************************************
 ******************************************************************************/
})();
