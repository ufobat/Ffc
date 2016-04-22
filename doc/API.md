Auth
====

* No Javascript API needed
    * GET  '/login'
        * HTML: loginpage.html.ep

* No Javascript API needed
    * POST '/login', {username: usernamestr, password: passwordstr}
        * HTML: page.html.ep

* No Javascript API needed
    * GET  '/logout'
        * HTML: loginpage.html.ep

Informations
============

* ffcapi.countings()
    * GET  '/countings'
        * <<topics_id, topics_title, topics_posts_count>, <users_id, users_name, users_posts_count>>

* ffcapi.topics_posts_get_new()
    * GET  '/topics/posts/get/new'
        * <<posts_id, users_id, users_name, users_color, ref_id, ref_description, ref_marker, create_time, textdata>>

* ffcapi.users_posts_get_new()
    * GET  '/users/posts/get/new'
        * <<posts_id, users_id, users_name, users_color, ref_id, ref_description, ref_marker, create_time, textdata>>

Topics
======

* ffcapi.topics_posts_get( topicsid, limit = 10, offset = 0 )
    * GET  '/topics/get/limit/:limit/offset/:offset'
        * <<topics_id, topics_title, users_id, topics_pin, topics_ignore, topics_posts_last_id>>

* ffcapi.topics_posts_add( topicsid, text )
    * POST '/topics/add', {title: titlestr}
        * bool

* ffcapi.topics_edit( topicsid, titlestr )
    * POST '/topics/:topicid/edit', {title: titlestr}
        * bool

* ffcapi.topics_pin( topicsid )
    * GET  '/topics/:topicsid/pin'
        * bool

* ffcapi.topics_unpin( topicsid )
    * GET  '/topics/:topicsid/unpin'
        * bool

* ffcapi.topics_ignore( topicsid )
    * GET  '/topics/:topicsid/ignore'
        * bool

* ffcapi.topics_unignore( topicsid )
    * GET  '/topics/:topicsid/unignore'
        * bool

GET  '/topics/:topicsid + '/posts/get/limit/' + limit + '/offset/' + offset
GET  '/posts/:postsid + '/topics/' + topicid + '/move/check'
GET  '/posts/:postsid + '/topics/' + topicid + '/move'
POST '/topics/search', { search: searchstr }
POST '/topics/:topicsid + '/posts/search', { search: searchstr }

# Users
GET  '/users/get'
GET  '/users/' + usersid + '/posts/get/limit/' + limit + '/offset/' + offset
POST '/users/' + usersid + '/posts/search', { search: searchstr }

# Postcreation
POST '/topics/' + topicsid + '/posts/add', {textdata: text}
POST '/users/' + usersid + '/add', {textdata: text}

# Posts
POST '/posts/' + postsid + '/edit', {textdata: text}
GET  '/posts/' + postsid + '/delete'
POST '/posts/' + postsid + '/delete'

# Comments
GET  '/posts/' + postsid + '/comments/get/limit/' + limit + '/offset/' + offset
POST '/posts/' + postsid + '/comments/add', {textdata: text}

# Attachements
GET  '/posts/' + postsid + '/attachements/get'
POST '/posts/' + postsid + '/attachements/add', {fields: attachementsfields}
GET  '/attachements/' + attachmentsid + '/get'
GET  '/attachements/' + attachementsid + '/delete'
POST '/attachements/' + attachementsid + '/delete'

# Userconfig
POST '/config/password/set', { npassword: npassword1 }
GET  '/config/usercolor/set/' + colorhex
GET  '/config/bgcolor/set/' + colorhex

# Adminconfig
GET  '/admin/config/get'
POST '/admin/title/set', { title: titlestr }
GET  '/admin/language/get/'
GET  '/admin/language/set/' + languagestr

# Adminusers
GET  '/admin/users/get'
POST '/admin/users/add', { name: namestr, password: passwordstr }
POST '/admin/users/' + usersid + '/name/edit', { name: namestr }
POST '/admin/users/' + usersid + '/password/set', {password: passwordstr }
POST '/admin/users/' + usersid + '/set/isadmin'
POST '/admin/users/' + usersid + '/set/notadmin'
POST '/admin/users/' + usersid + '/set/active'
POST '/admin/users/' + usersid + '/set/inactive'
