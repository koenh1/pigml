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
define(["orion/Deferred", "orion/plugin", "orion/mlFileImpl", "domReady!"], function(Deferred, PluginProvider, FileServiceImpl) {
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

  var tryParentRelative = true;
  function makeParentRelative(location) {
    if (tryParentRelative) {
      try {
        if (typeof window === "undefined") {
          return location.substring(self.location.href.indexOf(self.location.host) + self.location.host.length);
        }
        if (window.location.host === parent.location.host && window.location.protocol === parent.location.protocol) {
          return location.substring(parent.location.href.indexOf(parent.location.host) + parent.location.host.length);
        } else {
          tryParentRelative = false;
        }
      } catch (e) {
        tryParentRelative = false;
      }
    }
    return location;
  }



  function connect() {
    console.log('connecting')
     var headers = { login:"http://localhost:8040/login",name: "Connect Orion Plugin", version: "1.0", description: "Connect Orion Plugin." };
     var provider = new PluginProvider(headers);
     registerServiceProviders(provider)
    provider.connect();
    console.log('connected')
  }

  function registerServiceProviders(provider) {
    // note global
    var fileBase = "http://localhost:8040/orion/file";
  
    // note global
    var workspaceBase = "http://localhost:8040/orion/workspace";
  
    // note global
    var importBase = "http://localhost:8040/orion/xfer"
  
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

    provider.registerServiceProvider("orion.edit.validator", service,{ contentType: ['text/html','application/xquery',"text/xml","application/xml",'application/xslt+xml','application/rdf+xml','application/atom+xml','application/owl+xml','image/svg+xml','application/vnd.marklogic-tde+xml','application/vnd.marklogic.triples+xml','application/xhtml+xml']});

provider.registerServiceProvider("orion.edit.command", {
   run : function(selectedText, text, selection) {
     return service.prettyPrint(text,'application/xquery')
   }
 }, {
   contentType: ["application/xquery"],
   name : "PrettyPrint",
   id : "mp.prettyprint",
 });
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