/*******************************************************************************
 * @license
 * Copyright (c) 2010, 2012 IBM Corporation and others.
 * All rights reserved. This program and the accompanying materials are made 
 * available under the terms of the Eclipse Public License v1.0 
 * (http://www.eclipse.org/legal/epl-v10.html), and the Eclipse Distribution 
 * License v1.0 (http://www.eclipse.org/org/documents/edl-v10.html). 
 * 
 * Contributors: IBM Corporation - initial API and implementation
 ******************************************************************************/

/*eslint-env browser, amd*/
define(["orion/Deferred", "orion/plugin", "ext/orion/mlFileImpl","requirejs/domReady!"], function(Deferred, PluginProvider, FileServiceImpl) {
  function trace(implementation) {
    var method;
    var traced = {};
    for (method in implementation) {
      if (typeof implementation[method] === 'function') {
        traced[method] = function(methodName) {
          return function() {
            console.log(methodName);
            var arg;
            for (arg in arguments) {
              console.log(" [" + arg + "] " + arguments[arg]);
            }
            var result = implementation[methodName].apply(implementation, Array.prototype.slice.call(arguments));
            Deferred.when(result, function(json) {
              console.log(json);
            });
            return result;
          };
        }(method);
      }
    }
    return traced;
  }



  function connect() {
     var headers = { login:new URL("/file", self.location.href).href,name: "Connect Orion Plugin", version: "1.0", description: "Connect Orion Plugin." };
     console.log(headers)
     var provider = new PluginProvider(headers);
     registerServiceProviders(provider)
    provider.connect();
  }

  function registerServiceProviders(provider) {
    // note global
    var fileBase = new URL("/orion/file", self.location.href).href;
  
    // note global
    var workspaceBase = new URL("/orion/workspace", self.location.href).href;
  
    // note global
    var importBase = new URL("/orion/xfer", self.location.href).href;

    var compileBase = new URL("/static/orion/compile.html", self.location.href).href;
  
    var service = new FileServiceImpl(fileBase, workspaceBase);
    //provider.registerService("orion.core.file", trace(service), {
    provider.registerService("orion.core.file", service, {
      //Name: 'Orion Content',  // HACK  see https://bugs.eclipse.org/bugs/show_bug.cgi?id=386509
      Name: "ML Content",
      nls: 'orion/navigate/nls/messages',
      top: fileBase,
      ranking: -1,
      pattern: [fileBase, workspaceBase, importBase]
    });

  provider.registerServiceProvider("orion.edit.validator", service,
    { 
      name:"marklogic validator",
      contentType: ['text/html','application/xquery',"text/xml","application/xml",'application/xslt+xml','application/rdf+xml','application/atom+xml','application/owl+xml','image/svg+xml','application/vnd.marklogic-tde+xml','application/vnd.marklogic.triples+xml','application/xhtml+xml']}
    );

  provider.registerServiceProvider("orion.edit.command", {
   run : function(selectedText, text, selection) {
     return service.prettyPrint(text,'application/xquery')
   }
 }, {
   contentType: ["application/xquery"],
   name : "PrettyPrint",
   key:["p",true],
   id : "ml.prettyprint",
 });

  provider.registerServiceProvider("orion.edit.command", {
   run : function(selectedText, text, selection,fileName) {
     fileName=fileName.replace(fileBase,'/orion/file')
     return {uriTemplate: compileBase+"?fileBase="+fileBase+"&workspaceBase="+workspaceBase+"&file=" + fileName, width: "600px", height: "400px"};
     //return service.compile(text,'application/xquery').then(function(result){console.log(result);window.alert(result)})
   }
 }, {
   contentType: ["application/xquery"],
   key: ['r',true],
   name : "Compile",
   id : "ml.compile",
 });

/*
provider.registerServiceProvider("orion.page.link.category", null, {
      id: "compile",
      name: "Compile",
      imageClass: "core-sprite-wrench",
      order: 20         
   });

provider.registerServiceProvider("orion.page.link.related", null, {
    id: "ml.compile",
    category: "compile", 
    name: "Compile",
    contentType: ["application/xquery"],
    uriTemplate: '//'+document.location.host+"/static/orion/compile.html#{+Location}"
 });
*/


    provider.registerService("orion.cm.managedservice",
         {  updated: function(properties) {
            //console.log(properties)
            }
         },
         {  pid: "example.pid"
         });

    provider.registerService('orion.core.setting',
        {},  // no methods
        {  settings: [
               {  pid: 'example.pid',
                  name: 'Navigation settings',
                  category: 'Credentials',
                  properties: [
                      {
                        id:'userid',
                        name:"UserId",
                        type:'string',
                        defaultValue:'admin'
                      },
                      {
                        id:'password',
                        name:"PassWord",
                        type:'string',
                        defaultValue:'admin'
                      }
                  ]
               }
           ]
        });
  }

  return {
    connect: connect,
    registerServiceProviders: registerServiceProviders
  };
});