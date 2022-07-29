// CodeMirror, copyright (c) by Marijn Haverbeke and others
// Distributed under an MIT license: https://codemirror.net/LICENSE

(function(CodeMirror) {
  var Pos = CodeMirror.Pos;

  function forEach(arr, f) {
    for (var i = 0, e = arr.length; i < e; ++i) f(arr[i]);
  }

  function arrayContains(arr, item) {
    if (!Array.prototype.indexOf) {
      var i = arr.length;
      while (i--) {
        if (arr[i] === item) {
          return true;
        }
      }
      return false;
    }
    return arr.indexOf(item) != -1;
  }

  function scriptHint(editor, keywords, getToken, options) {
    // Find the token at the cursor
    var cur = editor.getCursor(), token = getToken(editor, cur);
    if (/\b(?:string|comment)\b/.test(token.type)) return;
    var innerMode = CodeMirror.innerMode(editor.getMode(), token.state);
    if (innerMode.mode.helperType === "json") return;
    token.state = innerMode.state;

    // If it's not a 'word-style' token, ignore the token.
    if (!/^[\w$_]*$/.test(token.string)) {
      token = {start: cur.ch, end: cur.ch, string: "", state: token.state,
               type: token.string == "." ? "property" : null};
    } else if (token.end > cur.ch) {
      token.end = cur.ch;
      token.string = token.string.slice(0, cur.ch - token.start);
    }

    var tprop = token;
    // If it is a property, find out what it is a property of.
    while (tprop.type == "property") {
      tprop = getToken(editor, Pos(cur.line, tprop.start));
      if (tprop.string != ".") return;
      tprop = getToken(editor, Pos(cur.line, tprop.start));
      if (!context) var context = [];
      context.push(tprop);
    }
    return {list: getCompletions(token, context, keywords, options, editor),
            from: Pos(cur.line, token.start),
            to: Pos(cur.line, token.end)};
  }

  function javascriptHint(editor, options) {
    return scriptHint(editor, javascriptKeywords,
                      function (e, cur) {return e.getTokenAt(cur);},
                      options);
  };
  CodeMirror.registerHelper("hint", "javascript", javascriptHint);

  function getCoffeeScriptToken(editor, cur) {
  // This getToken, it is for coffeescript, imitates the behavior of
  // getTokenAt method in javascript.js, that is, returning "property"
  // type and treat "." as indepenent token.
    var token = editor.getTokenAt(cur);
    if (cur.ch == token.start + 1 && token.string.charAt(0) == '.') {
      token.end = token.start;
      token.string = '.';
      token.type = "property";
    }
    else if (/^\.[\w$_]*$/.test(token.string)) {
      token.type = "property";
      token.start++;
      token.string = token.string.replace(/\./, '');
    }
    return token;
  }

  function coffeescriptHint(editor, options) {
    return scriptHint(editor, coffeescriptKeywords, getCoffeeScriptToken, options);
  }
  CodeMirror.registerHelper("hint", "coffeescript", coffeescriptHint);

  var stringProps = ("charAt charCodeAt indexOf lastIndexOf substring substr slice trim trimLeft trimRight " +
                     "toUpperCase toLowerCase split concat match replace search").split(" ");
  var arrayProps = ("length concat join splice push pop shift unshift slice reverse sort indexOf " +
                    "lastIndexOf every some filter forEach map reduce reduceRight ").split(" ");
  var funcProps = "prototype apply call bind".split(" ");
  var javascriptKeywords = ("break case catch class const continue debugger default delete else export extends false finally for function " +
                  "if in import instanceof new null return super switch this throw true typeof var void with yield").split(" ");
  var coffeescriptKeywords = ("and break catch class continue delete else extends false finally for " +
                  "if in instanceof isnt new no not null of off on or return switch then throw true typeof until void with yes").split(" ");

  var complexCompletions

  function hasVar(a,t) {
      if(t.state.context)
        for (var c = t.state.context; c; c = c.prev)
          for (var v = c.vars; v; v = v.next) if(v.name==a)return true
      for (var v = t.state.localVars; v; v = v.next) if(v.name==a)return true
        for (var v = t.state.globalVars; v; v = v.next) if(v.name==a)return true
        return false
    }

  function forAllProps(obj, callback) {
    if (!Object.getOwnPropertyNames || !Object.getPrototypeOf) {
      for (var name in obj) callback(name)
    } else {
      for (var o = obj; o; o = Object.getPrototypeOf(o))
        Object.getOwnPropertyNames(o).forEach(callback)
    }
  }

  function getCompletions(token, context, keywords, options, cm) {

    var found = [], start = token.string;
    function maybeAdd(str) {
      if (str.lastIndexOf(start, 0) == 0 && !arrayContains(found, str)) found.push(str);
    }

    function maybeAddComplex(shortcut, name, completionBeforeCursor, completionAfterCursor, func) {

      if (shortcut.lastIndexOf(start, 0) != 0) {
        return
      }

      addComplex(name, completionBeforeCursor, completionAfterCursor, func)
    }
    function addComplex(name, completionBeforeCursor, completionAfterCursor, func) {
      complex = {5:name,3:completionBeforeCursor}
        if(completionAfterCursor) complex[4] = completionAfterCursor
      if(func) complex[6] = func

      found.push(complex);
    }
    function gatherCompletions(obj) {
      if (typeof obj == "string") forEach(stringProps, maybeAdd);
      else if (obj instanceof Array) forEach(arrayProps, maybeAdd);
      else if (obj instanceof Function) forEach(funcProps, maybeAdd);
      forAllProps(obj, maybeAdd)
    }

    if (context && context.length) {

      // If this is a property, see if it belongs to some object we can
      // find in the current environment.
      var obj = context.pop(), base;
      if (obj.type && obj.type.indexOf("variable") === 0) {

        if (obj.string == "EasyHTML" && !hasVar("EasyHTML", token)) {
          maybeAdd("applicationLanguage")
          maybeAdd("deviceLanguage")
        }
        if (obj.string == "console" && !hasVar("console", token)) {
          maybeAddComplex("log",   "log(...)",   "log(",")")
          maybeAddComplex("warn",  "warn(...)",  "warn(",")")
          maybeAddComplex("info",  "info(...)",  "info(",")")
          maybeAddComplex("error", "error(...)", "error(",")")
          maybeAddComplex("debug", "debug(...)", "debug(",")")
          maybeAddComplex("error", "error(...)", "error(",")")

        }
        if (options && options.additionalContext) {
          base = options.additionalContext[obj.string];
        }
      } else if (obj.type == "string") {
        base = "";
      } else if (obj.type == "atom") {
        base = 1;
      }
      
      while (base != null && context.length)
        base = base[context.pop().string];
      if (base != null) gatherCompletions(base);
    } else {

      // If not, just look in the global object and any local scope
      // (reading into JS mode internals to get at the local and global variables)
      for (var v = token.state.localVars; v; v = v.next) maybeAdd(v.name);
      for (var v = token.state.globalVars; v; v = v.next) maybeAdd(v.name);
      
      windowProps.forEach(maybeAdd)

      forEach(keywords, maybeAdd);

      if(found.length < 10) {
        maybeAddComplex("function",   "function() {...}",      "function() {\n","\n}")
        maybeAddComplex("try",        "try {...} catch {...}", "try {\n","\n} catch(e) {\n\n}")
        maybeAddComplex("try",        "try {...} catch {...} finally {...}", "try {\n","\n} catch(e) {\n\n} finally {\n\n}")

        if("for".lastIndexOf(start, 0) == 0) {
          if(!cm._completeForCycle) setupForCycleCompletion(cm)
            debugger
          addComplex("for(i < array.length) {...}", "", "", "editor._completeForCycle(1)")
          addComplex("for(i < ...) {...}", "", "", "editor._completeForCycle(0)")
        }
        
        maybeAddComplex("setTimeout", "setTimeout(...)",       "setTimeout(function(){\n","\n}, 10);")
        maybeAddComplex("setInterval","setInterval(...)",      "setInterval(function(){\n","\n}, 10);")
        maybeAddComplex("if",         "if ...",                "if(cond",") {\n\n}")
        maybeAddComplex("if",         "if ... else ...",       "if(cond",") {\n\n} else {\n\n}")
        maybeAddComplex("while",      "while (...) {...}",     "while(cond",") {\n\n}")
        maybeAddComplex("do",         "do {...} while (...)",  "do {\n\n} while(cond",");")
      }
    }

    maybeAddComplex("forEach", "forEach", "forEach(function(element){\n","\n})")
    return found;
  }

  function setupForCycleCompletion(cm) {
    var forVarNames = ["i", "j", "k"]
    cm._completeForCycle = function(isArr) {
      var c = editor.getCursor()
      var t = cm.getTokenAt(cm.getCursor())
      cm.operation(function(){
        var i = -1
      while(true) {
        i++
        var variablename = forVarNames[i] || ("index" + i)
        
        if(hasVar(variablename, t)) continue

        if(isArr) {
          var lengthname = "l"
          if(i) lengthname += i
          if(hasVar(lengthname, t)) continue

          editor.replaceRange("for(var " + variablename + " = 0, " + lengthname + " = ", c, c)
          var nc = editor.getCursor()
          editor.replaceRange(".length; " + variablename + " < " + lengthname + "; " + variablename + "++) {\n\n}", nc, nc)
          editor.setCursor(nc)
        } else {
          editor.replaceRange("for(var " + variablename + " = 0; " + variablename + " < ", c, c)
          var nc = editor.getCursor()
          editor.replaceRange("; " + variablename + "++) {\n\n}", nc, nc)
          editor.setCursor(nc)
        }
        

        editor.indentLine(c.line,'smart',true);
        editor.indentLine(c.line + 1,'smart',true);
        editor.indentLine(c.line + 2,'smart',true);

        break
      }
      })
    }
  }
})(CodeMirror);
