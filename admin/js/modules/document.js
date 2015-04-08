(function(){
  'use strict';
  var app = window.LS || (window.LS = {});
  var u = LS.utils;

  // Document module
  app.document = {vm: {}};
  app.document.vm.init = function() {
    var vm = this;
    vm.dir = app.system.directory;
    vm.id = m.prop(m.route.param("id"));
    vm.action = m.route.param("action");
    vm.readOnly = true;
    vm.contentType = m.prop("");
    vm.updatedTags = m.prop("");
    try {
      vm.ext = vm.id().match(/\.(.+)$/)[1];
    } catch(e) {
      vm.ext = "";
    }
    vm.getDoc = function(cb){
      vm.doc = Doc.get(vm.id());
      vm.doc.then(function(doc){
        vm.content = doc.data;
        vm.tags = doc.tags;
      }, vm.flashError);
    };
    vm.viewDocument = function(){
      if (vm.ext === "md" && vm.id().match(new Regexp("^"+vm.dir+"\/md\/"))) {
        // If editing a documentation page, go back to the guide.
        m.route("/guide/"+vm.id().replace(/\.md$/, "").replace(new Regexp("^"+vm.dir+"\/md\/"), ""));
      } else {
        m.route("/document/view/"+vm.id());
      }
    };
    vm.tags = [];
    switch (vm.action) {
      case 'create':
        vm.readOnly = false;
        vm.content = "";
        break;
      case 'edit':
        vm.getDoc();
        vm.readOnly = false;
        break;
      case 'view':
        vm.getDoc();
        break;
    }
    vm.editTagsDialogCfg = {
      title: "Edit Tags",
      id: "edit-tags-modal",
      action: function(){
        // TODO
        console.log(vm.updatedTags());
      },
      actionText: "Update",
      content: m("input", {
            type: "text", 
            class:"form-control", 
            onchange: m.withAttr("value", vm.updatedTags),
            placeholder: "Enter comma-separated tags..."
          })
    };
    vm.edit = function(){
      vm.editor.setReadOnly(false);
      vm.action = "edit";
      vm.flash("");
    };
    vm.save = function(){
      var doc = {};
      doc.id = vm.id();
      doc.data = vm.editor.getValue();
      doc.tags = vm.tags;
      var put = function(){
        Doc.put(doc, vm.contentType()).then(function(){
          LS.flash({type: "success", content: "Document saved successfully."});
          vm.viewDocument();
        }, vm.flashError);
      };
      if (vm.action === "create") {
        doc.id = vm.dir+"/"+vm.id();
        vm.id(doc.id);
        Doc.get(doc.id)
          .then(function(){
            vm.showFlash({type: "danger", content: "Document '"+doc.id+"' already exists."});
          }, function(){
            put();
          });
      } else {
        put();
      }
    };
    vm.delete = function(){
      var msg = "Do you want to delete document '"+vm.id()+"'?";
      if (confirm(msg)) {
        Doc.delete(vm.id()).then(function(){
          LS.flash({type: "success", content: "Document '"+vm.id()+"' deleted successfully."});
          m.route("/info");
        }, vm.flashError);
      } else {
        m.route("/document/view/"+vm.id());
      }
    };
    vm.cancel = function(){
      if (vm.action === "create"){
        m.route("/info");
      } else {
        vm.viewDocument();
      }
    };
    vm.tools = function(){
      if (app.system.read_only) {
        return [];
      }
      // Configure edit tags popover
      var cfg = {};
      cfg.title = "Edit Tags";
      cfg.contentId = "#edit-tags-popover";
      switch (vm.action){
        case "view":
          return [
            {title: "Edit Content", icon: "edit", action: vm.edit},
            {title: "Edit Tags", icon: "tags", action: function(){$("#edit-tags-modal").modal()}},
            {title: "Delete", icon: "trash", action: vm.delete}
          ];
        default:
          return [
            {title: "Save", icon: "save", action: vm.save},
            {title: "Cancel", icon: "times-circle", action: vm.cancel}
          ];
      }
    };
  };
  app.document.main = function(){
    var vm = app.document.vm;
    var titleLeft = vm.id();
    var titleRight = m("span.pull-right", vm.tags.map(function(t){return u.taglink(t);}));
    if (vm.action === "create"){
        titleLeft = m("span", [vm.dir+"/",m("input", {
          placeholder: "Document ID",
          onchange: m.withAttr("value", function(value){
            vm.id(value);
            vm.editor.updateMode(value);
          }),
          size: 35,
          value: vm.id()
        })]);
        titleRight = m("span.pull-right", [m("input", {
          placeholder: "Content Type",
          onchange: m.withAttr("value", vm.contentType),
          size: 25,
          value: vm.contentType()
        })]);
    }
    var title = m("span",[titleLeft, titleRight]);
    return m("div", [
      u.modal(vm.editTagsDialogCfg),
      m(".row", [u.toolbar({links: vm.tools()})]),
      m(".row", [u.panel({title: title, content:app.editor.view(vm)})])
    ]);
  };
  
    u.layout(app.document);
}());