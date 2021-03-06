(function(){
  'use strict';
  var app = window.LS || (window.LS = {});
  
  app.flash = m.prop();
  app.system = {};
  m.route.mode = "hash";
  
  app.init = function(info){
    app.system = info;
    app.system.v = app.system.version.match(/(v.+)$/)[1];
    m.route(document.body, "/info", {
      "/info": app.info,
      "/html/:id...": app.htmldoc,
      "/document/:action/:id...": app.document,
      "/guide/:id": app.guide,
      "/new": app.create,
      "/tags/:id": app.tags,
      "/tags/:id/:page": app.tags,
      "/tags/:id/:page/:limit": app.tags,
      "/search/:q": app.search,
      "/search/:q/:page": app.search,
      "/search/:q/:page/:limit": app.search
    });
  };
  Info.get().then(app.init);
  
}());
