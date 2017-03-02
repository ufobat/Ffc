Ffc - A Bulletin Board System For Smaller Groups
================================================

![Screenshot](https://raw.github.com/4FriendsForum/Ffc/master/public/Screenshot.png)

![Screenshot Chat](https://raw.github.com/4FriendsForum/Ffc/master/public/Screenshot_Chat.png)

So here is my presentation of what is kind of a pet project of mine. It's tied to a call for supporters because, as you might recognize while reading and digging into it, there is a lot to revamp all over the whole project in order to bring it to a broader audience.

Installation information (in german language) is located here: [INSTALL.md on GitHub](https://github.com/4FriendsForum/Ffc/blob/master/INSTALL.md)

First of all I would like to introduce the project as such and the ideas that lead to this project. The project is called Ffc, an abbreviation from the depths of history so far away that even I do not remember anymore.

The intention of this project is to create a tiny, encapsulated social communication platform. For starters: this is not the next Bluebook+. It is in no way a globally available software platform for texting with your friends and foes, where everyone and their aunt needs to be registered at.

Instead the project should provide a small communication platform for everyone to set up on his own tiny web server with no need and no wish to have your wise spreading out words into the world.

In general the project aims to an online bulletin board and an overall communication platform for a selected group of registered users (ca 10 to 20 people at most). Therefore it provides an open topic based discussion board, private messages, an javascript driven instant chat system plus the feature of personal notes. Users are able to share text messages and data (files). Text messages can be formatted in a simple way that should mostly serve the possibility to structure the text instead of making it bling bling. Topics can be startet by any user in the system.

The interface in the web browser should be slim, slick and clean. It should provide easy access to all the valuable communication information. Every new post should ideally be one click away at most. The content input features should be easily to accessable for users, which is represented by the up front text input box on top of the pages.

Users are also able to adjust a small repertory of settings for themselves, for example the background color of the website. This tends to be useful when accessing the web page from, say, your office. There is also the ability to set up an avatar image, which is then presented next to your posts.

From a technical perspective I would like to achieve an easy to install and easy to set up system with very few dependencies. The system should be able to serve multiple seperate instances. Every instance should keep it's data in a seperate container, which is in fact a seperate directory containing files and the standalone database (SQLite). The only configuration option for an instance is an environment variable pointing to that instance specific directory, where everything else is stored in, even the configuration of the system. So the instances are transparent and portable on the system. It is also crucial that system administrators are able to set up a new instance by just running one single setup script. This script sets up an instance directory and the contained database. It generates random values for different security features and an administraion account in which all other configuations can be adjusted using the running web page. All that needs to be done is setting up a webserver with a corresponding environment variable pointing towards the respective instance directory.

But there are lots of features missing, there are lots of flaws in the overall software design and in the code as such. This is where help is essential.

First of all the software lacks multilingualism. This one was missing right at the start of the design phase, so this is my fault. Regarding the design phase: The structure of the code is far from perfect and needs some serious revamping.The code itself is - even in it's third iteration - ugly as hell. Finally, it is necessary to set up AJAX components for the board and message functions (besides the already existing components for the chat). This should pave the way to expand to further target systems like mobile apps.

The project is up and stable for several years now. The ideas have proven to be valuable for a specific audience, and I do see an urgent need for private and personal communication aside from the big players. I hope I can get some help on that vision. Thanks in advance.

Copyright und Lizenz
====================

Copyright (C) 2012-2017 by Markus Pinkert

This application is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

