/**
 * User: Robert Kehoe
 * Date: 02/Aug/13 16:37
 */

// The Menu items and links
var menu = [
  {
    title: "Home",
    url  : "/dashboard"
  },
  {
    title: "Colors",
    url  : "/colors"
  },
  {
    title: "Preferences",
    url  : "/preferences"
  },
  {
    title: "Test",
    url  : "/xmood"
  }
];

// For this "simple demo" we can change event to "pageinit", but for the more advanced features, it has to be bound to "pageshow"
$(document).on("pageshow", function (event) {

  var items = '', // menu items list
    ul = $(".mainMenu:empty");  // get "every" mainMenu that has not yet been processed

  for (var i = 0; i < menu.length; i++) {
    items += '<li><a href="' + menu[i].url + '" rel="external">' + menu[i].title + '</a></li>';
  }

  ul.append(items);
  ul.listview('refresh'); // use cache, as ".mainMenu:empty" will no longer work (append called!)
   
});